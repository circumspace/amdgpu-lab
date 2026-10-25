# Worm: a resident scheduler on the GPU

Worm is a tinygrad experiment on the RX 7900 XTX. One kernel is dispatched at
boot and never exits. It takes all 96 compute units and schedules all further
work itself, in software written in tinygrad UOps.

## Normal dispatch compared with Worm

| | Normal tinygrad (HCQ) | Worm |
|---|---|---|
| Who starts work | CPU writes a dispatch packet per kernel | One dispatch at boot |
| Who assigns work to CUs | Hardware dispatcher, per kernel | Software loop on each CU |
| Order between tasks | Full barrier between kernels | Per-task dependency counters |
| Local memory (LDS) | Allocated per kernel launch | Reserved once, handed out by software |
| Next-token graph choice | Back through the host queue | Decided on the GPU |
| New compiled code | New dispatch | Written to memory, then branched into |

## Where it helps

Batch-1 decode. Each step reads every weight once, so the ceiling is memory
bandwidth (about 960 GB/s) divided by model size. Launch gaps, barriers and
host round trips keep runtimes below that ceiling, and Worm removes them.
Hazy Research's megakernel got about 1.5x on small-Llama decode on NVIDIA with
the same idea; expect gains of that order.

Little or no gain for prefill, large-batch serving or training.

## Costs

- Register and LDS budget is fixed at boot and must fit the largest task.
- No preemption or fault isolation: one bad task hangs the GPU.
- Standard profilers and debuggers assume ordinary kernels.

## Direction from the author

- This is where things will go.
- No custom MEC firmware. Use the 96 CUs properly instead.
- Atomics are missing from the spec and need design work. The task queue and
  the dependency counters both depend on them.

## Related work

- Hazy Research, "Look Ma, No Bubbles": Llama-1B as one megakernel.
- CMU Mirage: compiler that emits persistent megakernels.
- Persistent-threads pattern on CUDA.
