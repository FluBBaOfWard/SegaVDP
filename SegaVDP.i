;@
;@  SegaVDP.i
;@  Sega VDP chip emulator for GBA/NDS.
;@
;@  Created by Fredrik Ahlström on 2012-03-10.
;@  Copyright © 2012-2023 Fredrik Ahlström. All rights reserved.
;@
;@ ASM header for the SegaVDP emulator
;@

//-----------------------------------------------------------vdp types
#define VDPAUTO			(0x00)		// Should not be used.
#define VDPTMS9918		(0x01)		// SG-1000, SC-3000, OMV, Coleco & MSX VDP
#define VDPSega3155066	(0x01)		// SG-1000 II VDP, TMS9918 and SN76489 in the same package (but with RGB output?)
#define VDPSega3155124	(0x02)		// Mark III & SMS1 VDP
#define VDPSega3155246	(0x03)		// SMS2 VDP
#define VDPSega3155313	(0x04)		// Mega Drive VDP (YM7101 /FC1001)
//#define VDPSega3155315	(0x04)		// Mega Drive / Pico VDP (YM7101 /FC1001)
#define VDPSega3155378	(0x05)		// GG VDP VA0, correct number or is it 5377?
//#define VDPSega3155487	(0x06)		// Mega Drive 1/2 VDP (vdp & sound) (Yamaha FC1004)
//#define VDPSega3155535	(0x05)		// GG VDP VA1, later version.
//#define VDPSega3155582	(0x05)		// GG VDP, later version?
//#define VDPSega3155660	(0x06)		// Mega Drive 2 VDP (vdp & sound)(Yamaha FC1004)
//#define VDPSega3155685	(0x08)		// Mega Drive 2 VDP (Toshiba TC6158AF)
//#define VDPSega3155700	(0x07)		// Nomad VDP (combined vdp, sound & Z80?)(Yamaha FF1004)
//#define VDPSega3155708	(0x06)		// Mega Drive 1/2? (Yamaha FC1004)
//#define VDPSega3155786	(0x08)		// Mega Drive 2 VDP (Toshiba T9N13BF)
//#define VDPSega3155960	(0x09)		// Mega Drive 2/3 VDP (combined vdp, sound & Z80?) (Yamaha FJ3002)
//#define VDPSega3156123	(0x0A)		// Mega Drive 3 / Pico VDP (combined M68K, Z80, VDP, YM2612) (Yamaha FQ8007), column -1 scroll fixed?

#define VDPTYPE_MASK	(0x07)

#define TVTYPEPAL		(0x80)	// 0x00=NTSC 0x80=PAL timing
#define GGMODE			(0x40)	// 0x00=normal 0x40=GG mode

//-----------------------------------------------------------vdp modes
#define VDPMODE_0		(0x00)
#define VDPMODE_1		(0x01)
#define VDPMODE_2		(0x02)
#define VDPMODE_3		(0x03)
#define VDPMODE_4		(0x04)
#define VDPMODE_4_224	(0x14)
#define VDPMODE_4_240	(0x24)
#define VDPMODE_5		(0x05)
#define VDPMODE_5_224	(0x15)
#define VDPMODE_5_240	(0x25)
#define VDPMODE_B		(0x88)

#define VDPHEIGHT_192	(0x00)
#define VDPHEIGHT_224	(0x10)
#define VDPHEIGHT_240	(0x20)

#define VDPMODE_MASK		(0x0F)
#define VDPMODE_HEIGHTMASK	(0x30)

#define VDPSTATESIZE	(0xE0)

	rclr				.req r4
	vdpptr				.req r12

							;@ SegaVDP.s
	.struct 0
dirtyTiles:			.space 0x200
vdpSpriteTileBuffer: .space 0x20
vdpSpritePosBuffer:	.space 0x20
vdpJumpTable:		.space 0x80	;@
vdpCtrlTable:		.space 0x10	;@
scrollBuff:			.space 320	;@ Horizontal scrollbuffer.
TMapBuff:			.space 320	;@ Tilemap buffer.
VRAMPtr:			.long 0
VRAMCopyPtr:		.long 0
vdpModesPtr:		.long 0
irqRoutine:			.long 0		;@
debounceRoutine:	.long 0
vdpScanlineHook:	.long 0
vdpTmpOAMBuffer:	.long 0
vdpDMAOAMBuffer:	.long 0
vdpDirtyTilesPtr:	.long 0
					.space 0x0C
vdpState:						;@
vdpAdr:				.long 0
vdpScanline:		.long 0
vdpBuff:			.byte 0,0	;@ vdpbuff + toggle need to be together in this way.
vdpToggle:			.byte 0,0
vdpBuffMD:			.byte 0
vdpCtrl:			.byte 0
vdpStat:			.byte 0		;@ VBlank + spr stat
vdpPending:			.byte 0		;@ line interrupt pending

vdpRegisters:
vdpMode1:			.byte 0
vdpMode2:			.byte 0
vdpNameTable:		.byte 0
vdpCTOffset:		.byte 0
vdpPGOffset:		.byte 0
vdpSATOffset:		.byte 0
vdpSPROffset:		.byte 0
vdpBDColor:			.byte 0
vdpXScroll:			.byte 0
vdpYScroll:			.byte 0
vdpCounter:			.byte 0
vdpMode3:			.byte 0
vdpMode4:			.byte 0
vdpHScrollAdr:		.byte 0
vdpReg0E:			.byte 0
vdpReg0F:			.byte 0
vdpMDRegs:			.space 0x10
vdpRegistersSize:

vdpPaletteRAM:		.space 0x80
vdpHCountLatch:		.byte 0
vdpHCountOffset:	.byte 0
vdpHCountBP:		.byte 0
vdpVCountBP:		.byte 0
vdpNametableLine:	.long 0
vdpScrollXLine:		.long 0
vdpScanlineBP:		.long 0
vdpType:			.byte 0
vdpTVType:			.byte 0
vdpGGMode:			.byte 0
vdpMode2Bak1:		.byte 0
vdpMode2Bak2:		.byte 0
vdpYScrollBak1:		.byte 0
vdpPGOffsetBak1:	.byte 0
vdpRealMode:		.byte 0
vdpCalcMode:		.byte 0
vdpHeightMode:		.byte 0
vdpLineState:		.byte 0
vdpPrimedVBl:		.byte 0
vdpDebouncePin:		.byte 0
vdpNTMask:			.byte 0
					.space 0x02
vdpScrollMask:		.long 0
vdpSprStop:			.long 0
vdpLineIRQ:			.long 0
vdpNextLineChange:	.long 0
					.space 0x04

vdpStateTable:
vdpZeroLine:		.long 0,0
vdpScrStartLine:	.long 0,0
vdpMidFrameLine:	.long 0,0
vdpEndFrameLine:	.long 0,0
vdpVBlLine:			.long 0,0
vdpVBlEndLine:		.long 0,0
vdp2ndLastScanline:	.long 0,0
vdpLastScanline:	.long 0,0
vdpTotalScanlines:	.long 0,0
					.space 0x04

vdpBgrMapOfs0:		.long 0
vdpBgrMapOfs1:		.long 0
vdpBgrTileOfs:		.long 0
vdpSprTileOfs:		.long 0
vdpSize:

;@----------------------------------------------------------------------------

