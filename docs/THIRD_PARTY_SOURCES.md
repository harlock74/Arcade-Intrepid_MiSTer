# Third-party sources and redistribution audit

The publication snapshot was audited against the project's pinned import manifests and the path-level `../NOTICE.md`. No concrete file-specific redistribution blocker was found. The Intel/Altera GPL-combination interpretation risk is disclosed below. Upstream headers are preserved.

| Component | Upstream and revision | Files/use | License and redistribution | Local changes |
|---|---|---|---|---|
| Project-authored Intrepid implementation | This repository; validated production source `f3dad505c86468a097808a476aba81f29a254825` | `Arcade-Intrepid.sv`, `rtl/intrepid/`, `rtl/pause/`, `rtl/hiscore/`, project tests, tools and documentation | GNU GPL version 3 or later as provided in root `LICENSE`, except files carrying their own terms | Original Intrepid-specific RTL and integration; behavior is derived from documented functional evidence rather than copied MAME driver source. |
| MiSTer framework | `MiSTer-devel/Template_MiSTer`, commit `3ea1134cf05d62c2b1db30362277a823d739ced2` | `sys/`, HPS, video, scaler, DDR and audio infrastructure | The Template GPL v2 reference text is retained at `LICENSES/GPL-2.0.txt`; full GPLv3 and LGPLv3 texts and the TEMLIB scaler notice are also supplied for the actual shipped file notices. Individual framework files retain their own terms. The root `LICENSE` applies only the owner's scoped GPL-3.0-or-later grant to owner-controlled contributions. | Imported framework files are byte-identical to the pinned revision except `sys/hps_io.sv`: the validated source contains an `INTREPID_HS_DIAG` read-only observer guarded by a macro that the production QSF does not define. `Arcade-Intrepid.qpf`, `.qsf`, and `.sv` were adapted from template counterparts for this core. |
| TV80 | `MiSTer-devel/InputTest_MiSTer`, commit `94bcd31211c32df5e7a5178c37349b426c2b9332` | `rtl/tv80/tv80e.v`, `tv80_core.v`, `tv80_alu.v`, `tv80_mcode.v`, `tv80_reg.v` | Guy Hutchison permissive notice, based on T80 by Daniel Wallner; reproduced in `LICENSES/TV80-notice.txt` and retained in source. Redistribution is permitted with the notice. | Files are byte-identical to the pinned revision; the project selects wrapper parameters/macros in its integration. |
| Intel/Altera-generated Quartus IP | Quartus/ACDS 17.0; inherited byte-for-byte from the pinned Template_MiSTer revision | PLL wrappers, implementations, reconfiguration RTL and supporting QIPs listed below | **Quartus(R) Prime License Agreement Version 17.0 (Web Download)** §§1, 2.5, 5, 6 and 20. Section 2.5 permits free distribution of the free source-form IP and derivatives only for programming Altera devices; notices remain intact. Intel material is not offered under GPL. Section 20 creates the disclosed conditional copyleft interpretation risk below. | No Intrepid-local generation or publication source change. `pll_cfg_hdmi.v` is an inherited upstream trim/derivative whose Intel notice and trim note remain intact. |
| MAME functional reference | MAME commit `2cba893d856fdef428fda5a085d10897a626059c`, mainly `src/mame/taito/roundup.cpp` and AY device code | Behavioral reference for maps, clocks, video, inputs and sound; MAME source is not vendored here | MAME source used is BSD-3-Clause. AY attribution and license text are in `LICENSES/MAME-AY8910-notice.txt`. | Intrepid RTL is an implementation from the functional evidence, not a copy of the MAME driver and not a PCB-equivalence claim. |
| MiSTer Main references | Main_MiSTer parser `371e110c613c2c2549d62ae4197044c0933fba59`; NVRAM research `f80abdc79e76bfc63799d028f2337c4d762b5e50` | Reference-only understanding of MRA/menu/NVRAM host behavior | No Main source is redistributed in this repository. | None. |

The production AY-compatible RTL is project-authored using MAME behavioral/numerical references, with attribution preserved under the included notice; this is not a claim of copied MAME driver source. JT49 was evaluated during development but is not included. No game ROM, PROM dump, NVRAM image, or MAME source snapshot is included.

Per-file import tracking is preserved privately; the component revisions, attribution and conditions are retained here and in original source headers.


## Intel/Altera Quartus 17 redistribution basis

The relied-on text is **QUARTUS(R) PRIME LICENSE AGREEMENT VERSION 17.0
(WEB DOWNLOAD)**, copyright 2017 Altera Corporation, supplied with Quartus
Prime Lite 17.0 in `licenses/license.txt`. The official Quartus 17.0 download
page identifies the Version 17.0 software, Update 2 build 602, Cyclone V device
support, and the matching “Quartus Prime Design Software (includes FPGA IP)
License Agreements” archive. The exact installed agreement used for this audit
was independently preserved and hashed in the private development evidence;
the full agreement is not copied into this public repository.

Section 1 defines “IP Megafunctions or Components” to include RTL, netlists,
simulation models and other design/support files for an Altera logic device,
while excluding a function governed by a separate MegaCore agreement. Section
2.5 says IP megafunctions/components supplied free of charge in source form may
be modified, made into derivative works and freely distributed, including the
modifications/derivatives, provided they are used only to program Altera
Devices. Section 5 requires proprietary notices to remain; section 6 preserves
the device restriction and excepts uses expressly permitted elsewhere in the
agreement. No file-specific MegaCore or third-party override was found for
these ordinary Altera PLL/PLL Reconfig instances.

All following files are byte-identical to Template_MiSTer commit
`3ea1134cf05d62c2b1db30362277a823d739ced2`; none was generated locally for
Intrepid:

| Group | Exact public paths | Generator/IP evidence and retained notice |
|---|---|---|
| Gameplay PLL | `rtl/pll.qip`; `rtl/pll.v`; `rtl/pll/pll_0002.qip`; `rtl/pll/pll_0002.v` | Altera PLL, ACDS 17.0 build 602. `pll.v` retains the 1991–2020 Altera copyright, Altera-PLD-only megafunction notice and “wizard-generated” warning. The implementation/QIPs carry the instance and IP metadata but no separate legal header. |
| Audio PLL | `sys/pll_audio.qip`; `sys/pll_audio.v`; `sys/pll_audio/pll_audio_0002.qip`; `sys/pll_audio/pll_audio_0002.v`; `sys/pll_audio.13.qip` | Altera PLL; current wrapper is ACDS 17.0 build 602 and the compatibility QIP records IP tool 13.1. `pll_audio.v` retains the same 1991–2020 Altera/device-only notice; supporting files have no separate legal header. |
| HDMI PLL | `sys/pll_hdmi.qip`; `sys/pll_hdmi.v`; `sys/pll_hdmi/pll_hdmi_0002.qip`; `sys/pll_hdmi/pll_hdmi_0002.v`; `sys/pll_hdmi.13.qip` | Altera PLL; current wrapper is ACDS 17.0 build 598 and the compatibility QIP records IP tool 13.1. `pll_hdmi.v` retains the 1991–2018 Altera/device-only notice; supporting files have no separate legal header. |
| Quartus 13 gameplay compatibility QIP | `sys/pll.13.qip` | Altera PLL IP assignment collateral recording IP tool 13.1; no separate legal header. It selects the same generated gameplay PLL source. |
| PLL reconfiguration | `sys/pll_cfg.qip`; `sys/pll_cfg/pll_cfg.v`; `sys/pll_cfg/altera_pll_reconfig_core.v`; `sys/pll_cfg/altera_pll_reconfig_top.v`; `sys/pll_cfg/pll_cfg_hdmi.v` | Altera PLL Reconfig, ACDS 17.0 build 598. `pll_cfg.v` retains the 1991–2018 Altera/device-only notice. The three reconfiguration units retain the 2001–2017 Intel copyright and conditional Program/MegaCore/other-applicable-agreement, Intel-device-only header. `pll_cfg_hdmi.v` also retains its note that unused portions of the original core were trimmed. The QIP has no separate legal header. |

`sys/pll_q13.qip` and `sys/pll_q17.qip` are Template_MiSTer selector files,
and `sys/pll_hdmi_adj.vhd` is Template_MiSTer HDMI PLL-control logic. They are
not Quartus-generated Intel/Altera IP, although they select or drive the IP
above. Original proprietary notices and device-use restrictions remain intact.

Redistribution conditions are met as follows:

| Condition | Status | Public evidence |
|---|---|---|
| Distribute only for programming Altera devices | PASS | The project targets Cyclone V in `Arcade-Intrepid.qsf`; QIPs identify Cyclone V; `NOTICE.md` and this section state the restriction. |
| Retain copyright and proprietary notices | PASS | The four generated wrappers and three reconfiguration units retain their complete original headers; no header was removed from the headerless supporting files. |
| Keep Intel files under their own terms rather than GPL | PASS | `NOTICE.md` and this document expressly separate the Intel terms from the root GPL. |
| Separate MegaCore/third-party override, if one applies | NOT APPLICABLE on the examined evidence | QIPs identify ordinary `altera_pll`/PLL Reconfig IP; no separate purchased MegaCore function or file-specific override is identified. |
| Export-control compliance | NOT APPLICABLE as a static repository-content check | Section 15 remains an obligation on each distributor where an export licence or approval is legally required; no extra repository file is prescribed by that clause. |

Section 20 expressly names GPL/LGPL within its open-source definition. It does
not impose a blanket ban on placing differently licensed files in one
repository. It is triggered if Intel Licensed Software or documentation is
combined or distributed with open-source software **in a manner that subjects
Intel or any portion of that licensed material to open-source licence
obligations**. The Intel files are therefore distributed under §2.5 and are
expressly excluded from the project GPL. Whether the build-integrated HDL and
single fitted FPGA image legally subject those files to GPL obligations is not
settled by the agreement itself or by common MiSTer practice. This is a
specific disclosed residual interpretation risk, not an automatic finding of
compatibility and not an automatic prohibition. No concrete contradictory
file-specific licence or triggered violation was found in this audit.
