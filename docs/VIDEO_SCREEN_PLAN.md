# Screen plan for the Phase I prototype video

Use the team's script with the following visuals. Record at readable zoom. The terminal commands below run from `/Users/Dhruv/Desktop/mca`.

| Scene / speaker | Show on screen | What to point out |
|---|---|---|
| 1 — Naman (0:00–0:45) | `docs/video_title.png`, containing **all five names**. | Project objective and team introduction. |
| 2 — Kavya (0:45–1:30) | `docs/cache_block_diagram.png`, then briefly show the `rtl/` and `tb/` folders in the code editor. | The requester, cache controller, line storage, and simulated main memory; 1 KB / 16 B = 64 lines. |
| 3 — Akhilesh (1:30–2:15) | `docs/address_breakdown.png` full screen. | 22-bit tag, 6-bit index, 4-bit offset. For aligned 32-bit reads, bits [3:2] choose one of four words. |
| 4 — Lakshay (2:15–3:30) | In `rtl/direct_mapped_cache.sv`, show `LOOKUP`, `MISS_REQUEST`, and `MISS_WAIT`. Run `make test` live, then show the first directed-test lines from `results/simulation.log`. | First read of `0x0` is a miss; `0x4`, `0x8`, `0xC` are hits; `0x400` conflicts with `0x0`. |
| 5 — Dhruv (3:30–4:40) | Show only summary lines with `rg '^SUMMARY|ALL TESTS PASSED' results/simulation.log`. | Sequential 12/16 hits, repeated 15/16, conflict 0/16; all tests pass. Finish with Phase II write extension. |

## Commands to prepare and record

```sh
cd /Users/Dhruv/Desktop/mca
make test
```

For Scene 4, after the live run, show the compact directed evidence:

```sh
sed -n '2,9p' results/simulation.log
```

For Scene 5, show the trace results without scrolling through every access:

```sh
rg '^SUMMARY|ALL TESTS PASSED' results/simulation.log
```

The full waveform is `results/cache.vcd` if you have a VCD viewer. The script explicitly permits **simulation output**, so the terminal evidence above is sufficient for the video. The report and README can use the waveform file as an additional artifact.

Keep the terminal and editor at a readable font size. Do one rehearsal before recording, and export a video shorter than five minutes.
