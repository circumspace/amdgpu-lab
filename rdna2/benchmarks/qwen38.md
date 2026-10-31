# Qwen3.8 Flash Next on the 6700 XT

Recorded 2026-10-30 on benchmark-host, RX 6700 XT with 64 GiB dual-channel RAM. These
are experiments, not a production replacement. Source: the infrastructure
working-tree `benchmark-host/llm/README.md`; raw logs and outputs are on benchmark-host under
`~/llm/eval/strata-qwen38/extended-20261030T115936Z/` and
`~/llm/eval/results/overnight-compare-20261030/`.

## llama.cpp ROCm

SC117's abliterated Flash Next GSQ-RCO Q2_0, 128k context, one slot,
43 CPU expert layers, mmap and lazy loading; projector on CPU. On b11804,
a 3,826-token prompt read at 240 tok/s and generated at 18.3 tok/s. A
113,865-token marker prompt read at 159 tok/s and recalled its marker; peak
VRAM was 10.15 GiB of 11.98 GiB. A gateway follow-up reused 8,930 cached
prompt tokens. At 128k, 40 CPU expert layers ran out of VRAM; 42 used more
VRAM for the same 18.3 tok/s. A 1 GiB expert cache and n-gram speculation gave
no meaningful gain in short trials. Q4 MTP accepted 87/148 draft tokens but
slowed the short trial to 16.6 tok/s with the draft on CPU.

An isolated b11865 comparison measured 18.91 tok/s without speculation and
18.82 with the IncoAI DFlash2 Q4_K_M draft on GPU, at 43 CPU expert layers.
The draft accepted 101/243 tokens and peaked at 10.91 GiB VRAM; a 30,397-token
marker prompt read at 216 tok/s and returned the marker. Its seven-token
answer is too short to characterize decode. DFlash2 was not deployed.

With warm model files, switching via llama-swap took 11.07 seconds from a
Qwen3.6 request to Qwen3.8's first token, and 10.74 seconds in reverse on a
17-token prompt. Only one model is resident; cold disk and longer prompts add
latency.

## Strata versus llama.cpp

Strata 0.1.54, 128k context, int8 KV, 32k resident KV, same Q2 weights. A
paired test used a 30,440-token coding prompt:

| Measurement | Strata | llama.cpp b11865 |
|---|---:|---:|
| Prompt reading | 208 tok/s | 217 tok/s |
| Generation | 22.9 tok/s | 16.9 tok/s |
| 113,865-token marker prompt reading | 202 tok/s | 162 tok/s |
| Marker retrieved | Yes | Yes |

These are recorded paired runs, not broad quality or output-equivalence tests.
A separate 30,397-token Strata run read at 210 tok/s and generated 256 tokens
at 23.7 tok/s before reaching the output limit; peak VRAM was 10.84 GiB.
Production Qwen3.6 `:fast` read the same 30k and 113k prompts at 834 and
493 tok/s and generated the 30k response at 57.9 tok/s, but used its production
sampling filters rather than the greedy Qwen3.8 settings.

## Quality limits

A three-task July SWE-bench Live comparison graded Qwen3.8 2/3 in 3h41m and
Qwen3.6 1/3 in 21m; Qwen3.6's empty submission hit a context-window error. An
ungraded Mini run of Qwen3.8 produced 9.3–9.5 tok/s in long agent turns before
being canceled. On five small coding probes Qwen3.8 passed four and Qwen3.6
passed two; both passed one tool-call probe. These small samples do not establish
which model is better. Concurrent requests, vision, broader refusal tests and
long-context reliability remain untested for Qwen3.8.
