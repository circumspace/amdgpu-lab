# SWE-bench-Live MultiLang slice (2026-10-26)

One task per language from [SWE-bench-Live/MultiLang](https://huggingface.co/datasets/SWE-bench-Live/MultiLang),
all created in July 2026, after the model's release: the median-sized task per
language with at most two changed files ([../runs/swelive-tasks.tsv](../runs/swelive-tasks.tsv)).
Python, Go and TypeScript have no tasks after June 2026.

mini-swe-agent 2.4.6 (`swebench.yaml` plus llm-bench `swebench/local.yaml`: 150
steps, temperature 0.6), graded with SWE-bench-Live's harness (`62d0293`,
RepoLaunch `c4b623d`). Production flags at **64k context** so r126 fits; r126 with
`GGML_HIP_FA_BAND_FETCH_AHEAD=0 LLAMA_SPEC_NGRAM_MOD_BAND_CLAMP=0`. Script:
[../runs/swelive-run.sh](../runs/swelive-run.sh).

**Reference patches on benchmark-host:** 4 of 6 pass. The JS (gsd-core) and Rust
(obscura) tasks fail even with the reference fix and are excluded.

| Task | Language | upstream b11804 | rdna-boosts r126 |
|---|---|---|---|
| codegraph-1318 | C | context window exceeded, no patch | repeated format errors, no patch |
| Mooncake-2892 | C++ | wrong fix | wrong fix |
| UnitsNet-1698 | C# | wrong fix | wrong fix |
| floci-1908 | Java | **solved** | wrong fix |
| **Solved** | | **1 / 4** | **0 / 4** |

| | upstream b11804 | rdna-boosts r126 |
|---|---|---|
| Agent time, all 6 tasks | 61 min | 81 min |
| Peak VRAM (of 12,272 MiB) | 10,845 MiB | 12,254 MiB |

- Four tasks cannot rank the two builds. r126 took a third longer for the same
  work and left 18 MiB of VRAM at 64k.
- On fresh non-Python tasks the model solved 1 of 4, against 27/50 on the older
  Python SWE-bench Verified Mini, which it has likely seen in training.
- The C task filled the 64k context; production's 128k might have gone further.
- A useful rerun: production at 128k, two or three tasks per language, each
  checked with its reference patch first.
