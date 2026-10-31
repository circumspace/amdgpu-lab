# Qwen3.6 on benchmark-host: recorded results

Transcribed from the infrastructure working-tree report `benchmark-host/llm/QWEN36-BENCHMARKS.md` on 2026-10-31; detailed logs remain on benchmark-host.

Current recommendation remains upstream llama.cpp with DSpark + n-gram on ROCm.
On the dual-channel machine, it delivers roughly 60 tok/s for fresh code,
38 tok/s after a 117k prompt, and substantially faster copy-heavy edits.
Strata and Vulkan were slower; the RDNA boosts fork improved shallow
chunk-prefill but regressed at 120k.

These are recorded measurements, not new benchmark runs. Unless noted
otherwise, the model is the uncensored/heretic Qwen3.6-35B-A3B IQ4_XS on the
RX 6700 XT. Results before the RAM upgrade used 32 GiB single-channel; later
results used 64 GiB dual-channel. Pairs such as `60.0 / 60.7` are temperatures
0 / 0.6.

Whole-prompt prefill, a 512-token prefill chunk at an existing depth, and token
generation measure different things. Their rates should not be ranked against
one another.

## Current production: DSpark + n-gram

The direct dual-channel comparison that led to deploying DSpark:

| Workload | Previous MTP + n-gram | DSpark + n-gram |
|---|---:|---:|
| Generate after 3.8k prompt | 63.8 tok/s | 66.7 tok/s |
| Generate after 117k prompt | 30.4 | 37.9 |
| Read 117k prompt | 461 | 487 |
| Fresh code, temperature 0 / 0.6 | 60.0 / 58.6 | 60.0 / 60.7 |
| Copy-heavy edit, temperature 0 | 136.4 | 149.2 |
| Thinking chat, temperature 0 / 0.6 | 53.9 / 50.0 | 56.2 / 63.9 |

The clearest gain was 25% faster generation at 117k. Fresh-code speed was
roughly level. Some chat and edit cells varied substantially between runs.

A later isolated b11865 run of DSpark + n-gram measured 1,049 / 491 tok/s
whole-prompt reading at 3.8k / 117k, 67.2 / 38.3 tok/s generation after those
prompts, and 59.4 / 57.4 tok/s fresh code. It was not deployed.

### DSpark draft length

| DSpark + n-gram | Generate at 3.8k | Generate at 117k | Fresh code, temp 0 / 0.6 | Peak VRAM |
|---|---:|---:|---:|---:|
| Default draft length | 66.7 | 37.9 | 60.0 / 60.7 | 11,763 MiB |
| Seven-token drafts | 43.7 | 27.9 | 43.1 / 44.1 | 12,242 MiB |

Seven-token drafts were slower and left only 30 MiB VRAM headroom in that run.
They are not a safe production choice.

Source logs: `~/llm/eval/dspark35b.out` and `~/llm/eval/b11865.out` on the
benchmark host; they are not included in this repository.

## RAM upgrade

Same probe family, before and after moving from single-channel 2933 MT/s to
dual-channel 3200 MT/s. These measurements used the then-production MTP +
n-gram configuration, not the later DSpark default.

| Workload | Single-channel | Dual-channel |
|---|---:|---:|
| Read 3.8k prompt | 994 tok/s | 1,039 tok/s |
| Read 117k prompt | 450 | 461 |
| Generate after 3.8k | 49.1 | 66.3 |
| Generate after 117k | 27.3 | 30.8 |
| Fresh code, temp 0 / 0.6 | 47.5 / 45.4 | 61.6 / 59.6 |
| Thinking chat, temp 0 / 0.6 | 42.6 / 43.8 | 49.1 / 54.0 |

The RAM upgrade primarily helped generation with host-resident experts;
prompt reading improved much less.

## Backend and runtime comparisons

### ROCm vs Vulkan

Same model, 24 CPU expert layers, 131k context, two slots and DSpark + n-gram.

| Workload | ROCm | Vulkan |
|---|---:|---:|
| Read 3,826-token prompt | 1,041 tok/s | 898 tok/s |
| Short generation | 40.1 | 26.9 |
| Read 113,852-token prompt | 495 | 300 |
| Generate after long prompt | 31.4 | 17.0 |
| Two concurrent requests, per request | 19.3–28.1 | 11.8–14.8 |

Short results were medians of three warm runs; long and concurrent results were
single runs. The serving paths and sampler filtering were not perfectly matched,
and no formal output-equivalence or peak-VRAM comparison was recorded.

### Strata vs llama.cpp

On the 30,440-token coding prompt, with each runtime's regular serving settings:

| Workload | Strata | Production llama.cpp |
|---|---:|---:|
| Prompt reading | 427 tok/s | 834 tok/s |
| Generation | 20.3 | 57.9 |
| 113,865-token marker prompt reading | 199 | 493 |
| Marker retrieved | Yes | Yes |

Strata's presence penalty disabled its MTP drafts. In a separate greedy,
zero-penalty paired probe, Strata generated at 22.2 tok/s versus llama.cpp's
35.7 tok/s; Strata accepted 102/124 drafts. These were single runs, not a
quality or numerical-equivalence study.

The Strata test required a temporary GGUF copy with 60 SSM tensors expanded from
their stored IQ4_XS values to FP32; it did not recover pre-quantization
precision. Source: `~/llm/eval/strata-q36/` and
[reproduction posted upstream](https://github.com/Niko1221/Strata/pull/3925#issuecomment-6543059064).

### RDNA boosts fork: latest matched-upstream test

This is a 512-token prefill chunk at the stated existing context depth, not a
whole-prompt or generation benchmark.

| Existing context | Matched upstream | RDNA boosts fork | Fork change |
|---|---:|---:|---:|
| 0 | 763 tok/s | 1,030 tok/s | +35% |
| 32k | 513 | 569 | +11% |
| 120k | 273 | 236 | −14% |

Two passes per main arm; two interleaved fetch-ahead-off passes were effectively
identical to fetch-ahead-on. Both builds forced native quantized KV reads. The
test used 28 CPU expert layers, rather than production's 24, and disabled the
fork's automatic MoE cache after it crossed the VRAM safety guard.

The older r126 full-server comparison on single-channel RAM was also
unfavorable for long prompts: approximately 360 tok/s vs 428–429 upstream at
117k. It left only 30–52 MiB VRAM free, so it is not a viable deployment
configuration.

Sources: `~/llm/eval/results/rdna-followup-20261031T140019/`,
[latest issue report](https://github.com/stew675/llama-cpp-rdna-boosts/issues/214#issuecomment-6544156284),
[r126 report](https://github.com/stew675/llama-cpp-rdna-boosts/issues/214#issuecomment-6403393421).

## Speculative decoding experiments

### Original single-channel MTP comparison

| Workload | N-gram only | MTP only | MTP + n-gram, draft on GPU |
|---|---:|---:|---:|
| Generate after 3.8k | 29.2 tok/s | 31.7 | 31.4 |
| Generate after 117k | 15.1 | 21.1 | 21.0 |
| Copy-heavy edit, temp 0 / 0.6 | 108.3 / 112.2 | 47.9 / 47.9 | 114.3 / 115.8 |
| Fresh code, temp 0 / 0.6 | 29.8 / 29.5 | 45.8 / 46.3 | 45.1 / 44.9 |

MTP improved fresh generation and deep-context decode; n-gram retained the
large advantage on copy-heavy edits. The MTP configurations required a smaller
microbatch, reducing short / deep prefill by approximately 22% / 15% relative
to the earlier no-draft setup.

### N-gram maximum draft length

Single-channel, copy-heavy edit; temperatures 0 / 0.6:

| N-gram maximum | Edit | Fresh code |
|---|---:|---:|
| 128 | 144.8 / 154.7 tok/s | 44.7 / 42.6 |
| 256 | 169.9 / 182.2 | 44.7 / 41.4 |
| 512 | 185.7 / 200.3 | 43.1 / 41.0 |

Larger drafts helped this highly repetitive edit, not fresh code. These are not
measurements of the current DSpark configuration.

### MTP draft depth

A later single-channel test found MTP draft lengths 2 and 3 broadly within
noise for fresh code: 44.8 / 44.5 versus 46.1 / 43.5 tok/s. MTP-only rewrites
were about 45–49 tok/s, while MTP + wide n-gram reached 138–180 tok/s, depending
on temperature and draft length.

Greedy versus probabilistic MTP draft sampling showed no clear speed winner
within the observed roughly 2–5% noise.

Sources: `~/llm/eval/nmax-sweep.out`, `nmax512.out`, `abtest-mtpdepth.out`,
`sds-ab.out`, and the
[upstream discussion](https://github.com/stew675/llama-cpp-rdna-boosts/issues/214).

## Placement, caching and serving levers

| Experiment | Recorded result | Interpretation |
|---|---|---|
| 24 vs 25 CPU expert layers, single-channel | 49 vs 30 tok/s | One more layer in RAM caused a large generation penalty in that configuration. |
| Expert-layer placement, same 16-layer GPU budget | 67.6 / 68.4 / 69.2 tok/s at 3.8k for tail / scattered / first-layer placement | Differences were small; no established placement win. |
| Upstream MoE cache, Q4 draft KV | No cache: fresh 44.3 / 41.7; 512 MiB cache: 42.0 / 38.8 tok/s | No gain in this run. Larger configurations were skipped for insufficient VRAM headroom. |
| Two simultaneous requests, dual-channel | 31–33 tok/s each, vs about 62 tok/s alone | Aggregate throughput is similar; individual requests slow down. |
| 117k context parked in other slot, idle-slot caching disabled | Fresh generation 62 → 31 tok/s | Keeping that context resident materially hurts the other request. |
| Long prompt beside a short request | Short request waited about 4.6 minutes | Prompt processing holds the other slot. |
| Four context checkpoints | Follow-up first token 0.41–0.42 s at 26k, 0.4–0.7 s at 108k | Avoids re-reading most of the conversation. Without checkpoints: 29.7 s at 26k, 51 s at 30k in older single-channel runs. |
| Vision token cap, 4000×3000 image | 115 s at 4096 tokens; about 12 s at 1024 | Current lower cap trades small-text detail for latency. |

Sources: `~/llm/eval/reap-run.out`, `moecache-sweep.out`,
`np2test-ncmoe24.out`, `sweep.out`, and the infrastructure working-tree `benchmark-host/llm/README.md`.

## Recorded quality and task results

| Evaluation | Result | Qualification |
|---|---:|---|
| SWE-bench Verified Mini | 27/50 | IQ4_XS, mini-swe-agent; Oct 19 run. |
| SWE-bench smoke | 5/5 in 35:45 | MTP + n-gram GPU; n-gram-only baseline was 5/5 in 47:10. |
| SWE-bench Verified Mini quick12 | 7/12 in 75 min | Earlier reference: 6/12 in 124 min. Small sample; one grading error, so not evidence of a quality gain from RAM. |
| July SWE-bench Live, three tasks | 1/3 in 21 min | One empty submission hit a context-window error. |
| Tool calling, older Q4_K_M run | 21/21 | Small targeted suite. |
| Coding, older Q4_K_M run | 12/12 | Small targeted suite. |
| Recall, older Q4_K_M run | 12/12 at 70k; 11/12 at 120k | Targeted recall, not general long-context reliability. |
| Later small coding probes | 2/5 | Different probes and settings; not directly comparable to the 12-task suite. |

The quality results do not establish that one inference backend or speculative
decoding configuration made the model more intelligent. Most speed experiments
did not include formal correctness or output-equivalence testing.

## Records

The infrastructure working-tree record is `benchmark-host/llm/README.md`; detailed logs remain
under `~/llm/eval/` on benchmark-host, particularly `results/`, `strata-q36/`, and the
`.out` files named above. The tables consolidate the recorded experiment
families; raw logs contain individual repetitions, failed starts and per-task
details.
