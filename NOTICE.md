# Licensing and attribution notice

This repository uses component-by-component licensing. The root `LICENSE`
grants GPL-3.0-or-later for copyrightable contributions controlled by the
project owner. It does not claim ownership of inherited modules or replace
their original notices. `NOTICE.md` is the component attribution notice.

## Project-authored Intrepid material

The Intrepid machine, video, audio, Pause and Autosave Hiscores RTL under
`rtl/intrepid/`, `rtl/pause/` and `rtl/hiscore/`, plus the project tests,
contracts, scripts, tools and documentation, are project work under the scoped
GPL-3.0-or-later owner grant. `Arcade-Intrepid.sv` is adapted from the pinned
Template_MiSTer top level; only its project-authored portions fall within that
owner grant. The upstream GPL-2.0-or-later header remains intact.

## MiSTer framework

The `sys/` framework and build infrastructure are pinned to
Template_MiSTer commit `3ea1134cf05d62c2b1db30362277a823d739ced2`.
The import manifest proves the shipped byte relation; it is a demonstrated
comparison/source pin and does not invent a different historical import.

| Component group | Paths and purpose | Credited authors/notices | Local relation |
|---|---|---|---|
| Top level, HPS and build support | `sys/sys_top.v`, `sys/hps_io.sv`, `sys/emu_ports.vh`, `sys/sys*.qip`, `sys/sys*.tcl`, `sys/sys_top.sdc`, `sys/build_id.tcl`, `sys/osd.v` | Alexey Melnikov/Sorgelig and Till Harbaum where named; mixed GPL-2.0-or-later, GPL-3.0-or-later and Template package context | Imported from the pin. `hps_io.sv` alone retains the documented compile-disabled `INTREPID_HS_DIAG` read-only observer. |
| Video and scaler | `sys/arcade_video.v`, `sys/ascal.vhd`, `sys/gamma_corr.sv`, `sys/hq2x.sv`, `sys/scandoubler.v`, `sys/scanlines.v`, `sys/shadowmask.sv`, `sys/vga_out.sv`, `sys/video_*.sv`, `sys/yc_out.sv` | Sorgelig/Alexey Melnikov, Till Harbaum, Ludvig Strigeus, Grabulosaure, Mike Simone and TEMLIB where named; GPL-family notices plus TEMLIB's permissive notice | Imported unchanged from the pin. |
| Audio helpers | `sys/alsa.sv`, `sys/audio_out.sv`, `sys/i2s.v`, `sys/iir_filter.v`, `sys/mt32pi.sv`, `sys/sigma_delta_dac.v`, `sys/spdif.v` | Alexey Melnikov/Sorgelig, Kitrinx and Ultra-Embedded where named; GPL-2.0-or-later or Template package context | Imported unchanged from the pin. |
| Memory, storage and board I/O | `sys/ddr_svc.sv`, `sys/f2sdram_safe_terminator.sv`, `sys/sd_card.sv`, `sys/sysmem.sv`, `sys/i2c.v`, `sys/ltc2308.sv`, `sys/mcp23009.sv`, `sys/math.sv` | Alexey Melnikov/Sorgelig, Till Harbaum and bellwood420 where named; GPL-3.0-or-later, LGPL-3.0-or-later or Template package context | Imported unchanged from the pin. |

Complete GPLv2, GPLv3 and LGPLv3 texts are supplied in `LICENSES/`.
`LICENSES/TEMLIB-ascal-notice.txt` reproduces the scaler's custom notice.
Original source headers remain authoritative.

## TV80 CPU

The five files under `rtl/tv80/` are byte-identical to
MiSTer-devel/InputTest_MiSTer commit
`94bcd31211c32df5e7a5178c37349b426c2b9332`. They credit Guy Hutchison
(2004; `tv80_mcode.v` also says 2007), are based on Daniel Wallner's T80, and
retain their permissive copyright, condition and warranty disclaimer.
`LICENSES/TV80-notice.txt` reproduces the complete required notice and both
copyright-year forms for documentation accompanying source/binary releases.

## Intel/Altera generated IP

The PLL and PLL-reconfiguration design files and supporting QIPs under
`rtl/pll*`, `sys/pll_*`, `sys/pll_cfg/` and the related compatibility QIPs are
separately licensed under the **Quartus(R) Prime License Agreement Version
17.0 (Web Download)**. Section 2.5 permits the free source-form IP
megafunctions/components and their derivatives to be distributed only for
programming Altera devices. Sections 5 and 6 preserve proprietary notices and
the device-use condition. These files are not offered under the project GPL.

Section 20 conditionally prohibits combining or distributing Intel licensed
material in a manner that subjects it to open-source licence obligations. It
does not automatically prohibit differently licensed files from appearing in
one repository. Whether the build-integrated HDL/RBF legally subjects the
Intel material to GPL obligations remains a disclosed interpretation risk,
not a claimed exception or guaranteed clearance. Exact paths and retained
headers are recorded in `docs/THIRD_PARTY_SOURCES.md`.

## Functional references

MAME commit `2cba893d856fdef428fda5a085d10897a626059c`, particularly
`src/mame/taito/roundup.cpp` and the AY8910 implementation, was used as a
functional reference. MAME source is not shipped. The AY RTL is project-authored from MAME behavioral/numerical references;
this describes the functional reference, not a claim of copied driver source.
The AY reference credit and
BSD-3-Clause notice are reproduced in `LICENSES/MAME-AY8910-notice.txt`.
MiSTer Main revisions recorded in `docs/THIRD_PARTY_SOURCES.md` were consulted
for MRA/menu/NVRAM host behavior; Main source is not shipped. JT49 was only a
development candidate and is not included.

No Intrepid ROM, PROM dump, NVRAM image or saved score is distributed.
