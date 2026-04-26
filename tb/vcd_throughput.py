#!/usr/bin/env python3
"""
Streaming VCD analyzer for the Z-Core control-unit testbench.

Computes pipeline / cache throughput metrics from
tb/z_core_control_u_tb.vcd, with end-of-test self-loop trimming and a
"pipeline full" metric (all four pipeline-stage valid bits set).

A "polluted" window starts when the same `if_id_pc` is consumed
SAME_PC_THRESHOLD cycles in a row (the test has reached its end-of-test
infinite self-jump) and lasts until the next rstn rising edge.
Cycles inside a polluted window are excluded from the "useful" metrics.
"""
import sys
import os
from collections import defaultdict

VCD = sys.argv[1] if len(sys.argv) > 1 else "z_core_control_u_tb.vcd"

SAME_PC_THRESHOLD = 8  # consume_inst pulses on identical if_id_pc.

# Signal IDs we extracted from the VCD header (top-level uut scope).
SIG = {
    "clk":               "K",
    "rstn":              "O",
    # Pipeline-stage valid bits.
    "if_id_valid":       "_&",
    "id_ex_valid":       "Z&",
    "ex_mem_valid":      ":&",
    "mem_wb_valid":      "i&",
    # Pipeline-stage PC.
    "if_id_pc":          "^&",
    # Fetch / cache events.
    "inst_fetch_pulse":      "(%",
    "inst_cache_miss_pulse": "'%",
    "cache_hit_q":       "o$",
    "cache_miss_q":      "p$",
    "consume_inst":      "q$",
    "deliver_direct":    "{$",
    "deliver_from_cache":"|$",
    # Stalls / flushes.
    "stall":             "B%",
    "flush":             "#%",
    "load_use_hazard":   "0%",
    "ex_stall":          "\"%",
    "mem_stall":         "8%",
    "div_stall":         "~$",
    "prediction_flush":  "A%",
    "mret_in_ex":        ">%",
    "trap_enter_r":      "m&",
    # Memory.
    "mem_ready":         "I%",
    "mem_busy":          "K%",
    # Misc.
    "pc_q_valid":        "l&",
    "fetch_wait":        "<&",
}
ID2NAME = {v: k for k, v in SIG.items()}

# CSR counters from uut.u_csr_file (64-bit regs)
#  mcycle_r       : c(
#  minstret_r     : p(
#  mhpmcounter3_r : f(  (icache hits)
#  mhpmcounter5_r : h(  (memory reads)
#  mhpmcounter6_r : i(  (memory writes)
CSR_SIG = {
    "mcycle": "c(",
    "minstret": "p(",
    "cache_hits": "f(",
    "mem_reads": "h(",
    "mem_writes": "i(",
}
CSR_ID2NAME = {v: k for k, v in CSR_SIG.items()}

# Testbench CSR-accumulated mirrors (read from CSR before each reset_cpu).
TB_CSR_ACC_SIG = {
    "acc_cache_hits": "Q",
    "acc_cycles": "R",
    "acc_instrs": "S",
    "acc_mem_reads": "T",
    "acc_mem_writes": "U",
}
TB_CSR_ACC_ID2NAME = {v: k for k, v in TB_CSR_ACC_SIG.items()}

state_bit = {name: 0 for name in SIG if name != "if_id_pc"}
state_pc = 0  # if_id_pc current value
state_csr = {name: 0 for name in CSR_SIG}
state_tb_csr_acc = {name: 0 for name in TB_CSR_ACC_SIG}

# All vs useful counters (useful excludes end-of-test self-loop windows).
class Counters:
    __slots__ = (
        "cycles", "retired", "consume_inst", "deliver_direct",
        "deliver_from_cache", "cache_hit_q", "cache_miss_q",
        "stall", "flush", "fetch_wait", "mem_busy",
        "inst_fetch_pulse", "inst_cache_miss_pulse",
        "load_use", "ex_stall", "mem_stall", "div_stall",
        "prediction_flush", "trap_enter", "mret",
        "if_id_valid", "id_ex_valid", "ex_mem_valid", "mem_wb_valid",
        "pipeline_full", "mem_ready",
    )
    def __init__(self):
        for s in self.__slots__:
            setattr(self, s, 0)


all_c = Counters()
useful_c = Counters()

# Sustained 1-IPC streaks (consume_inst back-to-back) within USEFUL window.
current_streak = 0
longest_streak = 0
streak_hist = defaultdict(int)

# Self-loop detection.
prev_if_id_pc = None
same_pc_run = 0       # consume_inst pulses with same if_id_pc as last consume.
in_polluted_window = False
trimmed_cycles_total = 0

# Per-test (per rstn rising edge) snapshots, so the threshold cycles can
# be retroactively un-counted from the useful counters.
test_idx = 0
useful_at_test_start = None
streak_hist_at_test_start = None
last_streak_at_test_start = 0
per_test = []  # list of dicts with summary per test

prev_clk = 0
prev_rstn = 0


def update_counters(c, st, pc_full, sign=1):
    c.cycles += sign
    c.retired += sign * st["mem_wb_valid"]
    c.consume_inst += sign * st["consume_inst"]
    c.deliver_direct += sign * st["deliver_direct"]
    c.deliver_from_cache += sign * st["deliver_from_cache"]
    c.cache_hit_q += sign * st["cache_hit_q"]
    c.cache_miss_q += sign * st["cache_miss_q"]
    c.stall += sign * st["stall"]
    c.flush += sign * st["flush"]
    c.fetch_wait += sign * st["fetch_wait"]
    c.mem_busy += sign * st["mem_busy"]
    c.inst_fetch_pulse += sign * st["inst_fetch_pulse"]
    c.inst_cache_miss_pulse += sign * st["inst_cache_miss_pulse"]
    c.load_use += sign * st["load_use_hazard"]
    c.ex_stall += sign * st["ex_stall"]
    c.mem_stall += sign * st["mem_stall"]
    c.div_stall += sign * st["div_stall"]
    c.prediction_flush += sign * st["prediction_flush"]
    c.trap_enter += sign * st["trap_enter_r"]
    c.mret += sign * st["mret_in_ex"]
    c.if_id_valid += sign * st["if_id_valid"]
    c.id_ex_valid += sign * st["id_ex_valid"]
    c.ex_mem_valid += sign * st["ex_mem_valid"]
    c.mem_wb_valid += sign * st["mem_wb_valid"]
    c.pipeline_full += sign * pc_full
    c.mem_ready += sign * st["mem_ready"]


def snapshot_counter(c):
    return {s: getattr(c, s) for s in c.__slots__}


def diff_snapshots(end, start):
    return {k: end[k] - start[k] for k in end}


# Track the recent per-cycle samples so we can retract them when we
# realize we crossed into a polluted window.
recent_samples = []  # list of (state_bit_dict_copy, pc_full) for last K
RETRACT_BUF = SAME_PC_THRESHOLD


with open(VCD, "rb") as f:
    in_header = True
    for raw in f:
        line = raw.decode("ascii", errors="replace").rstrip("\n")
        if in_header:
            if line.startswith("$enddefinitions"):
                in_header = False
            continue
        if not line:
            continue
        c0 = line[0]
        if c0 == "#":
            continue
        if c0 in ("0", "1", "x", "z", "X", "Z"):
            sig_id = line[1:]
            if sig_id not in ID2NAME:
                continue
            name = ID2NAME[sig_id]
            new_val = 1 if c0 == "1" else 0

            if name == "clk":
                # Only act on rising edge.
                if prev_clk == 0 and new_val == 1:
                    rstn_now = state_bit["rstn"]
                    # rstn rising edge => start of a new test window.
                    if prev_rstn == 0 and rstn_now == 1:
                        test_idx += 1
                        useful_at_test_start = snapshot_counter(useful_c)
                        per_test.append({
                            "test_idx": test_idx,
                            "start_useful": useful_at_test_start,
                            "start_csr": dict(state_csr),
                            "trimmed_cycles": 0,
                        })
                    if rstn_now == 1:
                        cons = state_bit["consume_inst"]
                        # Detect/track same-PC streak.
                        if cons:
                            if state_pc == prev_if_id_pc:
                                same_pc_run += 1
                            else:
                                same_pc_run = 1
                                prev_if_id_pc = state_pc
                        pc_full = (state_bit["if_id_valid"]
                                   & state_bit["id_ex_valid"]
                                   & state_bit["ex_mem_valid"]
                                   & state_bit["mem_wb_valid"])
                        update_counters(all_c, state_bit, pc_full)
                        if not in_polluted_window:
                            update_counters(useful_c, state_bit, pc_full)
                            recent_samples.append((dict(state_bit), pc_full))
                            if len(recent_samples) > RETRACT_BUF:
                                recent_samples.pop(0)
                            # Threshold trip => retroactively un-count
                            # the SAME_PC_THRESHOLD cycles already
                            # added (they were already inside the loop).
                            if cons and same_pc_run >= SAME_PC_THRESHOLD:
                                in_polluted_window = True
                                for s, pf in recent_samples:
                                    update_counters(useful_c, s, pf, sign=-1)
                                    trimmed_cycles_total += 1
                                    if per_test:
                                        per_test[-1]["trimmed_cycles"] += 1
                                recent_samples.clear()
                                # Also kill any in-flight streak counted
                                # within those cycles.
                                if current_streak >= SAME_PC_THRESHOLD:
                                    current_streak -= SAME_PC_THRESHOLD
                                    if current_streak < 0:
                                        current_streak = 0
                            else:
                                if cons:
                                    current_streak += 1
                                    if current_streak > longest_streak:
                                        longest_streak = current_streak
                                else:
                                    if current_streak:
                                        streak_hist[current_streak] += 1
                                        current_streak = 0
                        else:
                            trimmed_cycles_total += 1
                            if per_test:
                                per_test[-1]["trimmed_cycles"] += 1
                    else:
                        # rstn = 0: tear down per-test state.
                        if per_test and useful_at_test_start is not None:
                            per_test[-1]["end_useful"] = snapshot_counter(useful_c)
                            per_test[-1]["end_csr"] = dict(state_csr)
                        in_polluted_window = False
                        same_pc_run = 0
                        prev_if_id_pc = None
                        recent_samples.clear()
                        if current_streak:
                            streak_hist[current_streak] += 1
                            current_streak = 0
                    prev_rstn = rstn_now
                prev_clk = new_val
            else:
                state_bit[name] = new_val
        elif c0 == "b":
            # Multi-bit value change: 'b<bits> <id>'.
            sp = line.find(" ")
            if sp < 0:
                continue
            sig_id = line[sp + 1:]
            bits = line[1:sp]
            # iverilog dumps 'x'/'z' for unknown; treat them as 0.
            try:
                v = int(bits.replace("x", "0").replace("z", "0"), 2)
            except ValueError:
                v = 0
            if sig_id == SIG["if_id_pc"]:
                state_pc = v
            if sig_id in CSR_ID2NAME:
                state_csr[CSR_ID2NAME[sig_id]] = v
            if sig_id in TB_CSR_ACC_ID2NAME:
                state_tb_csr_acc[TB_CSR_ACC_ID2NAME[sig_id]] = v
        # other types ignored


def pct(n, d):
    return 100.0 * n / d if d else 0.0


def report(label, c):
    print(f"\n========== {label} ==========")
    print(f"Cycles                 : {c.cycles}")
    if c.cycles == 0:
        return
    print(f"Retired (mem_wb_valid) : {c.retired}")
    print(f"IPC                    : {c.retired / c.cycles:.4f}")
    print(f"Consume-inst pulses    : {c.consume_inst}  "
          f"({pct(c.consume_inst, c.cycles):.2f}%)")
    if c.consume_inst:
        print(f"  via direct AXI fill  : {c.deliver_direct}  "
              f"({pct(c.deliver_direct, c.consume_inst):.2f}% of consumes)")
        print(f"  via cache hit        : {c.deliver_from_cache}  "
              f"({pct(c.deliver_from_cache, c.consume_inst):.2f}% of consumes)")
    print()
    print(f"Cache hits  (lookups)  : {c.cache_hit_q}")
    print(f"Cache miss  (lookups)  : {c.cache_miss_q}")
    if c.cache_hit_q + c.cache_miss_q:
        print(f"Hit rate (per lookup)  : "
              f"{pct(c.cache_hit_q, c.cache_hit_q + c.cache_miss_q):.2f}%")
    print(f"AXI mem_ready pulses   : {c.mem_ready}")
    print()
    print(f"Stall cycles           : {c.stall}  ({pct(c.stall, c.cycles):.2f}%)")
    print(f"  load-use             : {c.load_use}")
    print(f"  ex-stall             : {c.ex_stall}")
    print(f"    mem-stall          : {c.mem_stall}")
    print(f"    div-stall          : {c.div_stall}")
    print(f"Flush cycles           : {c.flush}  ({pct(c.flush, c.cycles):.2f}%)")
    print(f"  prediction-flush     : {c.prediction_flush}")
    print(f"  trap-enter           : {c.trap_enter}")
    print(f"  mret-in-EX           : {c.mret}")
    print(f"Fetch-wait cycles      : {c.fetch_wait}  "
          f"({pct(c.fetch_wait, c.cycles):.2f}%)")
    print(f"Mem-busy cycles        : {c.mem_busy}  "
          f"({pct(c.mem_busy, c.cycles):.2f}%)")
    print()
    print("---- Pipeline stage occupancy ----------------------------------")
    print(f"IF/ID  valid           : {c.if_id_valid:>6d}  "
          f"({pct(c.if_id_valid, c.cycles):.2f}%)")
    print(f"ID/EX  valid           : {c.id_ex_valid:>6d}  "
          f"({pct(c.id_ex_valid, c.cycles):.2f}%)")
    print(f"EX/MEM valid           : {c.ex_mem_valid:>6d}  "
          f"({pct(c.ex_mem_valid, c.cycles):.2f}%)")
    print(f"MEM/WB valid           : {c.mem_wb_valid:>6d}  "
          f"({pct(c.mem_wb_valid, c.cycles):.2f}%)")
    print(f"PIPELINE FULL (all 4)  : {c.pipeline_full:>6d}  "
          f"({pct(c.pipeline_full, c.cycles):.2f}%)")


print()
print("======================================================================")
print(" Z-Core Control-Unit VCD Throughput Analysis")
print(f" VCD: {os.path.abspath(VCD)}")
print(f" Self-loop trim threshold: {SAME_PC_THRESHOLD} consecutive same if_id_pc")
print("======================================================================")
report("ALL CYCLES (raw, includes end-of-test self-loops)", all_c)
report("USEFUL CYCLES (end-of-test self-loops trimmed)", useful_c)

# CSR totals from live architectural counters at simulation end
# (typically final test only, because each test resets CPU/CSRs).
csr_live = dict(state_csr)

# Full-suite CSR view from testbench accumulators that were themselves
# captured from CSRs before each reset_cpu, plus the currently running
# final test's live CSR values.
csr_suite = {
    "cycles": state_tb_csr_acc["acc_cycles"] + csr_live["mcycle"],
    "instrs": state_tb_csr_acc["acc_instrs"] + csr_live["minstret"],
    "cache_hits": state_tb_csr_acc["acc_cache_hits"] + csr_live["cache_hits"],
    "mem_reads": state_tb_csr_acc["acc_mem_reads"] + csr_live["mem_reads"],
    "mem_writes": state_tb_csr_acc["acc_mem_writes"] + csr_live["mem_writes"],
}
print()
print("========== CSR TOTALS (architectural counters) ==========")
print("Live CSR snapshot (usually final test only):")
print(f"mcycle                 : {csr_live['mcycle']}")
print(f"minstret               : {csr_live['minstret']}")
print(f"CSR IPC                : "
      f"{(csr_live['minstret'] / csr_live['mcycle']):.4f}" if csr_live["mcycle"] else "n/a")
print(f"mhpmcounter3 (i$ hits) : {csr_live['cache_hits']}")
print(f"mhpmcounter5 (dmem rd) : {csr_live['mem_reads']}")
print(f"mhpmcounter6 (dmem wr) : {csr_live['mem_writes']}")
print()
print("Full-suite CSR totals (accumulated from CSR reads):")
print(f"cycles                 : {csr_suite['cycles']}")
print(f"instructions           : {csr_suite['instrs']}")
print(f"CSR IPC                : "
      f"{(csr_suite['instrs'] / csr_suite['cycles']):.4f}" if csr_suite["cycles"] else "n/a")
print(f"i$ hits                : {csr_suite['cache_hits']}")
print(f"dmem reads             : {csr_suite['mem_reads']}")
print(f"dmem writes            : {csr_suite['mem_writes']}")
print()
print("======================================================================")
print(f"Trimmed (polluted) cycles : {trimmed_cycles_total}  "
      f"({pct(trimmed_cycles_total, all_c.cycles):.2f}% of total)")
print()
print("---- Per-test useful-window summary (post end-of-test trim) ----------")
print(f"  {'#':>3s}  {'cyc':>5s}  {'retire':>6s}  {'IPC':>6s}  "
      f"{'cons%':>6s}  {'pipfull%':>8s}  {'hit%':>6s}  "
      f"{'fwait%':>7s}  {'stall%':>7s}  {'trim':>5s}")
for t in per_test:
    if "end_useful" not in t:
        t["end_useful"] = snapshot_counter(useful_c)
    d = diff_snapshots(t["end_useful"], t["start_useful"])
    cyc = d["cycles"]
    if cyc <= 0:
        continue
    retired_t = d["retired"]
    cons_t = d["consume_inst"]
    pf_t = d["pipeline_full"]
    hit_t = d["cache_hit_q"]
    miss_t = d["cache_miss_q"]
    fw_t = d["fetch_wait"]
    st_t = d["stall"]
    print(f"  {t['test_idx']:>3d}  {cyc:>5d}  {retired_t:>6d}  "
          f"{retired_t / cyc:>6.3f}  "
          f"{pct(cons_t, cyc):>6.2f}  "
          f"{pct(pf_t, cyc):>8.2f}  "
          f"{pct(hit_t, hit_t + miss_t):>6.2f}  "
          f"{pct(fw_t, cyc):>7.2f}  "
          f"{pct(st_t, cyc):>7.2f}  "
          f"{t['trimmed_cycles']:>5d}")

print()
print("---- Sustained 1-IPC streaks (within useful window) -------------------")
print(f"Longest streak         : {longest_streak} cycles")
total_streaks = sum(streak_hist.values())
total_streak_len = sum(k * v for k, v in streak_hist.items())
avg_streak = total_streak_len / total_streaks if total_streaks else 0
print(f"Avg streak length      : {avg_streak:.2f}")
print(f"# streaks              : {total_streaks}")
buckets = [(1, 1), (2, 4), (5, 9), (10, 19), (20, 49), (50, 99), (100, 1 << 30)]
print("Streak length histogram:")
for lo, hi in buckets:
    n = sum(v for k, v in streak_hist.items() if lo <= k <= hi)
    cyc = sum(k * v for k, v in streak_hist.items() if lo <= k <= hi)
    label = (f"{lo}" if lo == hi
             else (f"{lo}+" if hi >= 1 << 29 else f"{lo}-{hi}"))
    print(f"   len={label:>7s} : {n:>4d} streaks ({cyc:>6d} cycles)")
print("======================================================================")
