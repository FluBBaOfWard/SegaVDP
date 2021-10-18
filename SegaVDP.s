#ifdef __arm__

#include "../ARMZ80/ARMZ80mac.h"
#include "SegaVDP.i"

	.global VDPReset
	.global VDPScanlineBPReset
	.global VDPClearDirtyTiles
	.global VDPSaveState
	.global VDPLoadState
	.global VDPGetStateSize

	.global defaultScanlineHook
	.global VDPNewFrame
	.global VDPDoScanline
	.global VDPCheckIRQ
	.global VDPLatchHCounter
	.global VDPSetMode
	.global VDPSetScanline

	.global ntFinnish
	.global VDPReg08W

	.global VDPVCounterR
	.global VDPHCounterR
	.global VDPDataSMSW
	.global VDPDataGGW
	.global VDPDataMDW
	.global VDPDataTMSW
	.global VDPDataR
	.global VDPStatR
	.global VDPCtrlW
	.global VDPCtrlMDW

	.global VDPGetRGBFromIndex
	.global VDPGetRGBFromIndexSG

	.syntax unified
	.arm

	.section .text
	.align 2
;@----------------------------------------------------------------------------
VDPReset:	;@ Called from gfxReset, r0=vdp/tv type, r1=irq routine, r2 = debounce routine, r12 = vdpptr.
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}

	and r3,r0,#TVTYPEPAL
	strb r3,[vdpptr,#vdpTVType]
	and r3,r0,#GGMODE
	strb r3,[vdpptr,#vdpGGMode]
	and r0,r0,#VDPTYPE_MASK			;@ Mask out VDP type
	strb r0,[vdpptr,#vdpType]
	cmp r1,#0
	adreq r1,VDPSetPinDummy
	str r1,[vdpptr,#irqRoutine]
	cmp r0,#VDPTMS9918
	moveq r2,#0						;@ TMS9918 doesn't have debounce circuit
	str r2,[vdpptr,#debounceRoutine]

	add r0,vdpptr,#vdpState
	mov r1,#(vdpRegisters-vdpState)/4
	bl memclr_						;@ Clear VDP state

	bl VDPMakeModes
	bl VDPSetupType
	bl VDPRegistersReset
	bl VDPVRAMReset
	bl VDPSetDefaultPalette			;@ Don't clear palette when loading a savestate.
	bl VDPScanlineBPReset
	bl VDPClearDirtyTiles
	bl VDPNewFrame
	bl earlyFrame

	ldmfd sp!,{pc}
;@----------------------------------------------------------------------------
VDPSaveState:				;@ In r0=destination, r1=vdpptr. Out r0=size.
	.type   VDPSaveState STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{r4,r5,lr}
	mov r4,r0					;@ Store destination
	mov r5,r1					;@ Store vdpptr (r1)

	ldr r1,[r5,#VRAMPtr]
	mov r2,#0x4000
	bl memcpy

	add r0,r4,#0x4000
	add r1,r5,#vdpState
	mov r2,#VDPSTATESIZE
	bl memcpy

	ldmfd sp!,{r4,r5,lr}
	ldr r0,=0x4000 + VDPSTATESIZE
	bx lr
;@----------------------------------------------------------------------------
VDPLoadState:				;@ In r0=vdpptr, r1=source. Out r0=size.
	.type   VDPLoadState STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{r4,r5,lr}
	mov r5,r0					;@ Store vdpptr (r0)
	mov r4,r1					;@ Store source

	ldr r0,[r5,#VRAMPtr]
	mov r2,#0x4000
	bl memcpy

	add r0,r5,#vdpState
	add r1,r4,#0x4000
	mov r2,#VDPSTATESIZE
	bl memcpy

	mov vdpptr,r5
	bl VDPClearDirtyTiles
	bl paletteTxAll

	ldmfd sp!,{r4,r5,lr}
;@----------------------------------------------------------------------------
VDPGetStateSize:			;@ Out r0=state size.
	.type   VDPGetStateSize STT_FUNC
;@----------------------------------------------------------------------------
	ldr r0,=0x4000 + VDPSTATESIZE
	bx lr
;@----------------------------------------------------------------------------
VDPRegistersReset:
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r6,lr}

	ldrb r0,[vdpptr,#vdpType]
	cmp r0,#VDPTMS9918
	ldr r4,=VDPRegsDefaults
	ldreq r4,=TMSRegsDefaults
	add r5,vdpptr,#vdpJumpTable
	ldrb r6,[r4],#1
RegResetLoop:
	ldrb r1,[r4],#1
	ldr r2,[r5],#4
	blx r2
	subs r6,r6,#1
	bne RegResetLoop

	ldmfd sp!,{r4-r6,pc}
;@----------------------------------------------------------------------------
VDPVRAMReset:				;@ Clear VDP RAM.
;@----------------------------------------------------------------------------
	mov r3,#-1
	mov r2,r3,lsl#16
	mov r3,r3,lsr#16
	ldr r0,[vdpptr,#VRAMPtr]
	mov r1,#0x4000/8
vramLoop:
	subs r1,r1,#1
	stmiapl r0!,{r2,r3}
	bhi vramLoop
	bx lr
;@----------------------------------------------------------------------------
;@VDPRegsDefaults:
;@----------------------------------------------------------------------------
;@ 0x0 Mode Control 1. mode2 & mode 4 bits set???, GG Bios = 0x16 (line IRQ on), SMS1 Bios = 0x36 (line IRQ + border on).
;@ 0x1 Mode Control 2. bit 7 set ?, GG & SMS1 Bios = 0xA0, bit 5 = frame interrupt enable.
;@ 0x2 Nametable. 0xFF?
;@ 0x3 Colortable. 0xFF?
;@ 0x4 Patterntable. 0xFF?
;@ 0x5 Sprite attribute. 0xFF?
;@ 0x6 Sprite patterntable. 0xFB? GG = 0xFF
;@ 0x7 Background color
;@ 0x8 Horizontal scroll
;@ 0x9 Vertical scroll
;@ 0xA IRQ counter. GG & SMS1 Bios = 0xFF.
;@ 0xB
;@ 0xC
;@ 0xD
;@ 0xE
;@ 0xF

TMSRegsDefaults:
	.byte 8
;@	       0x0   0x1   0x2   0x3   0x4   0x5   0x6   0x7
	.byte 0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
VDPRegsDefaults:
	.byte 16
;@	       0x0   0x1   0x2   0x3   0x4   0x5   0x6   0x7   0x8   0x9   0xA   0xB   0xC   0xD   0xE   0xF
	.byte 0x06, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
MDRegsDefaults:
//	.byte 32
;@	       0x0   0x1   0x2   0x3   0x4   0x5   0x6   0x7   0x8   0x9   0xA   0xB   0xC   0xD   0xE   0xF
//	.byte 0x06, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
;@	      0x10  0x11  0x12  0x13  0x14  0x15  0x16  0x17  0x18  0x19  0x1A  0x1B  0x1C  0x1D  0x1E  0x1F
//	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
	.align 2
;@----------------------------------------------------------------------------
VDPSetPinDummy:
;@----------------------------------------------------------------------------
	bx lr
;@----------------------------------------------------------------------------
VDPScanlineBPReset:
;@----------------------------------------------------------------------------
	ldrb r0,[vdpptr,#vdpTVType]
	tst r0,#TVTYPEPAL

	moveq r0,#0xDA					;@ NTSC
	ldreq r2,=261					;@ 262
	movne r0,#0xF2					;@ PAL
	ldrne r2,=312					;@ 313

	str r0,[vdpptr,#vdpScanlineBP]
	str r2,[vdpptr,#vdpLastScanline]
	sub r2,r2,#1
	str r2,[vdpptr,#vdp2ndLastScanline]
	add r2,r2,#2
	str r2,[vdpptr,#vdpTotalScanlines]

	bx lr
;@----------------------------------------------------------------------------
VDPMakeModes:
;@----------------------------------------------------------------------------
	adr r1,VDPModes_Sega3155246		;@ For SMS2 & GG.
	ldrb r0,[vdpptr,#vdpType]
	cmp r0,#VDPTMS9918
	adreq r1,VDPModes_TMS9918
	cmp r0,#VDPSega3155124
	adreq r1,VDPModes_Sega3155124
	cmp r0,#VDPSega3155313
	adreq r1,VDPModes_Sega3155313

	str r1,[vdpptr,#vdpModesPtr]
	bx lr

VDPModes_TMS9918:					;@ SG-1000, SC-3000, Coleco, MSX VDP
	.byte VDPMODE_0,VDPMODE_0,VDPMODE_3,VDPMODE_3,VDPMODE_1,VDPMODE_1,VDPMODE_B,VDPMODE_B
	.byte VDPMODE_2,VDPMODE_2,VDPMODE_B,VDPMODE_B,VDPMODE_B,VDPMODE_B,VDPMODE_B,VDPMODE_B
	.byte VDPMODE_0,VDPMODE_0,VDPMODE_3,VDPMODE_3,VDPMODE_1,VDPMODE_1,VDPMODE_B,VDPMODE_B
	.byte VDPMODE_2,VDPMODE_2,VDPMODE_B,VDPMODE_B,VDPMODE_B,VDPMODE_B,VDPMODE_B,VDPMODE_B

VDPModes_Sega3155124:				;@ SMS1 VDP
	.byte VDPMODE_0,VDPMODE_0,VDPMODE_3,VDPMODE_3,VDPMODE_1,VDPMODE_1,VDPMODE_B,VDPMODE_B
	.byte VDPMODE_2,VDPMODE_2,VDPMODE_B,VDPMODE_B,VDPMODE_B,VDPMODE_B,VDPMODE_B,VDPMODE_B
	.byte VDPMODE_4,VDPMODE_4,VDPMODE_4,VDPMODE_4,VDPMODE_B,VDPMODE_B,VDPMODE_B,VDPMODE_B
	.byte VDPMODE_4,VDPMODE_4,VDPMODE_4,VDPMODE_4,VDPMODE_B,VDPMODE_B,VDPMODE_B,VDPMODE_B

VDPModes_Sega3155246:				;@ SMS2 VDP
VDPModes_Sega3155378:				;@ GG VDP, correct number or is it 377?
	.byte VDPMODE_0,VDPMODE_0,VDPMODE_3,    VDPMODE_3,    VDPMODE_1,    VDPMODE_1,    VDPMODE_B,VDPMODE_B
	.byte VDPMODE_2,VDPMODE_2,VDPMODE_B,    VDPMODE_B,    VDPMODE_B,    VDPMODE_B,    VDPMODE_B,VDPMODE_B
	.byte VDPMODE_4,VDPMODE_4,VDPMODE_4,    VDPMODE_4,    VDPMODE_B,    VDPMODE_B,    VDPMODE_B,VDPMODE_B
	.byte VDPMODE_4,VDPMODE_4,VDPMODE_4_240,VDPMODE_4_240,VDPMODE_4_224,VDPMODE_4_224,VDPMODE_4,VDPMODE_4

VDPModes_Sega3155313:				;@ Mega Drive VDP
	.byte VDPMODE_B,VDPMODE_5_224,VDPMODE_B,VDPMODE_5_224,VDPMODE_B,VDPMODE_5_224,VDPMODE_B,VDPMODE_5_224
	.byte VDPMODE_B,VDPMODE_5_240,VDPMODE_B,VDPMODE_5_240,VDPMODE_B,VDPMODE_5_240,VDPMODE_B,VDPMODE_5_240
	.byte VDPMODE_4,VDPMODE_5_224,VDPMODE_4,VDPMODE_5_224,VDPMODE_4,VDPMODE_5_224,VDPMODE_4,VDPMODE_5_224
	.byte VDPMODE_4,VDPMODE_5_240,VDPMODE_4,VDPMODE_5_240,VDPMODE_4,VDPMODE_5_240,VDPMODE_4,VDPMODE_5_240

;@(M4)
;@(M2)
;@(M1)
;@(M3)
;@(M5)
;@----------------------------------------------------------------------------
VDPSetupType:
;@----------------------------------------------------------------------------
	stmfd sp!,{r4,lr}
	ldrb r4,[vdpptr,#vdpType]
	cmp r4,#VDPSega3155313			;@ MD VDP?

	moveq r0,#0x13					;@ Startup scanline on MegaDrive.
	ldrne r0,[vdpptr,#vdpTotalScanlines]	;@ number of scanlines
	blne getRandomNumber
	bl VDPSetScanline

	cmp r4,#VDPSega3155313			;@ MD VDP?
	mov r0,#12						;@ HCount 0xF4.
	moveq r0,#13					;@ HCount 0xF6 (second one).
	strb r0,[vdpptr,#vdpVCountBP]	;@ Which HCount VCount changes.
	mov r0,#27
	moveq r0,#31
	strb r0,[vdpptr,#vdpHCountBP]		;@ Which HCount HIRQ happens.
	strb r0,[vdpptr,#vdpHCountOffset]	;@ Offset for HC calculation.

	adr r1,VDPRegsSMS
	adreq r1,VDPRegsMD
	cmp r4,#VDPTMS9918
	adreq r1,VDPRegsTMS9918
	add r0,vdpptr,#vdpJumpTable

	mov r2,#32
VDPRegsLoop:
	ldr r3,[r1],#4
	str r3,[r0],#4
	subs r2,r2,#1
	bne VDPRegsLoop

	add r0,vdpptr,#vdpCtrlTable
	adr r1,VDPdest
	mov r2,#4
VDPCtrlLoop:
	ldr r3,[r1],#4
	str r3,[r0],#4
	subs r2,r2,#1
	bne VDPCtrlLoop

	cmp r4,#VDPTMS9918
	ldreq r1,=VDPctrl2W
	streq r1,[vdpptr,#vdpCtrlTable + 0x0C]
	mov r0,#0xE
	cmpne r4,#VDPSega3155124
	orrne r0,r0,#1
	strb r0,[vdpptr,#vdpNTMask]

	ldr r0,=vdpStateTable
	add r0,vdpptr,r0
	adr r1,VDPLineStateTable
	mov r2,#18
VDPLineStateLoop:
	ldr r3,[r1],#4
	str r3,[r0],#4
	subs r2,r2,#1
	bne VDPLineStateLoop

	ldmfd sp!,{r4,pc}

VDPRegsTMS9918:
	.long VDPReg00W, VDPReg01W, VDPReg02W, VDPReg03W, VDPReg04W, VDPReg05W, VDPReg06W, VDPReg07W
	.long VDPReg00W, VDPReg01W, VDPReg02W, VDPReg03W, VDPReg04W, VDPReg05W, VDPReg06W, VDPReg07W
	.long VDPReg00W, VDPReg01W, VDPReg02W, VDPReg03W, VDPReg04W, VDPReg05W, VDPReg06W, VDPReg07W
	.long VDPReg00W, VDPReg01W, VDPReg02W, VDPReg03W, VDPReg04W, VDPReg05W, VDPReg06W, VDPReg07W
VDPRegsSMS:
	.long VDPReg00W, VDPReg01W, VDPReg02W, VDPReg03W, VDPReg04W, VDPReg05W, VDPReg06W, VDPReg07W
	.long VDPReg08W, VDPReg09W, VDPReg0AW, VDPReg0FW, VDPReg0FW, VDPReg0FW, VDPReg0FW, VDPReg0FW
	.long VDPReg00W, VDPReg01W, VDPReg02W, VDPReg03W, VDPReg04W, VDPReg05W, VDPReg06W, VDPReg07W
	.long VDPReg08W, VDPReg09W, VDPReg0AW, VDPReg0FW, VDPReg0FW, VDPReg0FW, VDPReg0FW, VDPReg0FW
VDPRegsMD:
	.long VDPReg00W, VDPReg01MDW, VDPReg02W, VDPReg03W, VDPReg04W, VDPReg05W, VDPReg06W, VDPReg07W
	.long VDPReg08W, VDPReg09W, VDPReg0AW, VDPReg0FW, VDPReg0FW, VDPReg0FW, VDPReg0FW, VDPReg0FW
	.long VDPReg0FW, VDPReg0FW, VDPReg0FW, VDPReg0FW, VDPReg0FW, VDPReg0FW, VDPReg0FW, VDPReg0FW
	.long VDPReg0FW, VDPReg0FW, VDPReg0FW, VDPReg0FW, VDPReg0FW, VDPReg0FW, VDPReg0FW, VDPReg0FW
VDPdest:
	.long VDPctrl0W
	.long VDPctrl1W
	.long VDPctrl2W
	.long VDPctrl3W
VDPLineStateTable:
	.long 0, VDPNewFrame			;@ vdpZeroLine
	.long 0, earlyFrame				;@ vdpScrStartLine
	.long 96, midFrame
	.long 192, endFrame				;@ vdpEndFrameLine
	.long 192, startVbl				;@ vdpVBlLine
	.long 193, VBL_Hook				;@ vdpVBlEndLine
	.long 260, secondLastScanline	;@ vdp2ndLastScanline
	.long 261, lastScanline			;@ vdpLastScanline
	.long 262, frameEndHook			;@ vdpTotalScanlines
;@----------------------------------------------------------------------------
VDPSetScanline:				;@ in r0 = scanline
;@----------------------------------------------------------------------------
	mov r1,#0
	str r1,[vdpptr,#vdpNextLineChange]
	strb r1,[vdpptr,#vdpLineState]
	sub r0,r0,#1
	str r0,[vdpptr,#vdpScanline]	;@ Set scanline
	bx lr

;@----------------------------------------------------------------------------
VDPSetDefaultPalette:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	ldrb r0,[vdpptr,#vdpType]
	cmp r0,#VDPSega3155313			;@ MD VDP?
	adr r1,SMSDefaultPalette
	adreq r1,MDDefaultPalette

	add r0,vdpptr,#vdpPaletteRAM
	mov r2,#64
	bl bytecopy_

	ldmfd sp!,{pc}
;@----------------------------------------------------------------------------
SMSDefaultPalette:
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
MDDefaultPalette:
	.short 0x0FFF,0x0FFF,0x0FFF,0x0FFF,0x0FFF,0x0FFF,0x0FFF,0x0FFF,0x0FFF,0x0FFF,0x0FFF,0x0FFF,0x0FFF,0x0FFF,0x0FFF,0x0FFF
	.short 0x000F,0x0005,0x0000,0x0000,0x0FFF,0x0FFF,0x0FFF,0x0FFF,0x0FFF,0x0FFF,0x0FFF,0x0FFF,0x0FFF,0x0FFF,0x0AFF,0x0FFF

;@----------------------------------------------------------------------------
;@ This should not be used for realtime calculation of palette but filled in a LUT.
;@----------------------------------------------------------------------------
VDPGetRGBFromIndex:				;@ in r0=index, out r0=RGB.
;@----------------------------------------------------------------------------
	ldrb r1,[vdpptr,#vdpType]
	cmp r1,#VDPSega3155378			;@ GG VDP?
	beq VDPGetRGBFromIndexGG
	adr r3,SMS2ColorLevels			;@ SMS2 VDP
	cmp r1,#VDPSega3155124			;@ SMS1 VDP?
	adreq r3,SMS1ColorLevels
	cmp r1,#VDPSega3155313			;@ MD VDP?
	adreq r3,MegaDriveMSColorLevels
;@----------------------------------------------------------------------------
fetchRGBFromSMSLUT:
	mov r0,r0,lsr#2				;@ Convert bbbbggggrrrr -> bbggrr
	and r1,r0,#0x330
	orr r1,r1,r1,lsr#2
	and r1,r1,#0x0F0
	and r0,r0,#0x003
	orr r0,r0,r1,lsr#2

	and r1,r0,#0x03				;@ Red
	ldrb r1,[r3,r1]
	and r2,r0,#0x0C				;@ Green
	ldrb r2,[r3,r2,lsr#2]
	add r3,r3,#4
	ldrb r0,[r3,r0,lsr#4]		;@ Blue
	orr r0,r2,r0,lsl#8
	orr r0,r1,r0,lsl#8
	bx lr
;@----------------------------------------------------------------------------
VDPGetRGBFromIndexGG:			;@ bbbbggggrrrr -> bbbbbbbbggggggggrrrrrrrr
;@----------------------------------------------------------------------------
	mov r2,r0,lsr#8				;@ Blue
	and r1,r0,#0xF0				;@ Green
	and r0,r0,#0x0F				;@ Red
	orr r0,r0,r1,lsl#8
	orr r0,r0,r2,lsl#16
	orr r0,r0,r0,lsl#4
	bx lr
;@----------------------------------------------------------------------------
SMS2ColorLevels:
	.byte 0, 85,170,255	;@ RGB
SMS1ColorLevels:
	.byte 0, 85,170,255	;@ RG
	.byte 0,104,170,255	;@ B
MegaDriveMSColorLevels:
	.byte 0, 87,158,255	;@ RG
	.byte 0,101,158,255	;@ B

;@ MegaDrive Color levels.
;@ Normal : 0 52 87 116 144 172 206 255
;@ Shadow : 0 29 52 70 87 101 116 130
;@ HiLite : 130 144 158 172 187 206 228 255

;@----------------------------------------------------------------------------
VDPGetRGBFromIndexSG:			;@ index -> BGR24
;@----------------------------------------------------------------------------
	ldrb r1,[vdpptr,#vdpType]
	cmp r1,#VDPTMS9918
	bne mapSGFromSMS
	adr r3,SGPalette
	add r3,r3,r0
	ldrb r0,[r3,r0,lsl#1]!
	ldrb r1,[r3,#1]
	ldrb r2,[r3,#2]
	orr r0,r0,r1,lsl#8
	orr r0,r0,r2,lsl#16
	bx lr
;@----------------------------------------------------------------------------
mapSGFromSMS:
	adr r1,SGPaletteSMSIndex
	add r1,r1,r0,lsl#1
	ldrh r0,[r1]
	b VDPGetRGBFromIndex

;@----------------------------------------------------------------------------
SGPalette:						;@ RGB24
	.byte 0,0,0,     0,0,0,       36,218,36,  109,255,109, 36,36,255, 72,109,255,  182,36,36,   72,218,255
	.byte 255,36,36, 255,109,109, 218,218,36, 218,218,145, 36,145,36, 218,72,182,  182,182,182, 255,255,255

SGPaletteSMS:					;@ RGB24
	.byte 0,0,0,     0,0,0,       0,170,0,    0,255,0,     0,0,85,    0,0,255,     85,0,0,      0,255,255
	.byte 170,0,0,   255,0,0,     85,85,0,    255,255,0,   0,85,0,    255,0,255,   85,85,85,    255,255,255

;@TMS9918Palette:				;@ RGB24
;@	.byte 0,0,0,     0,0,0,       33,200,66,  94,220,120,  84,85,237, 125,118,252, 212,82,77,   66,235,245
;@	.byte 252,85,84, 255,121,120, 212,193,84, 230,206,128, 33,176,59, 201,91,186,  204,204,204, 255,255,255

SGPaletteSMSIndex:				;@ BGR12
	.short 0x000, 0x000, 0x0A0, 0x0F0, 0x500, 0xF00, 0x005, 0xFF0, 0x00A, 0x00F, 0x055, 0x0FF, 0x050, 0xF0F, 0x555, 0xFFF
;@----------------------------------------------------------------------------
VDPClearDirtyTiles:
;@----------------------------------------------------------------------------
	add r0,vdpptr,#dirtyTiles
	mov r1,#0x200/4
	b memclr_
;@----------------------------------------------------------------------------

;@----------------------------------------
VDPDoScanline:
	stmfd sp!,{lr}
	ldr r1,[vdpptr,#vdpScanline]
	add r1,r1,#1
	str r1,[vdpptr,#vdpScanline]
line0Ret:
	ldr r0,[vdpptr,#vdpNextLineChange]
	cmp r1,r0
	ldrmi pc,[vdpptr,#vdpScanlineHook]
	ldrb r2,[vdpptr,#vdpLineState]
	add r2,r2,#8
	strb r2,[vdpptr,#vdpLineState]
	add r1,vdpptr,#vdpStateTable-4
	ldrd r0,r1,[r1,r2]
	str r1,[vdpptr,#vdpNextLineChange]
	blxeq r0
	ldr r1,[vdpptr,#vdpScanline]
	b line0Ret

defaultScanlineHook:
;@----------------------------------------------------------------------------
	bl SpriteParserM4
checkScanlineIRQ:
	ldr r0,[vdpptr,#vdpLineIRQ]
	subs r0,r0,#1
	ldrbmi r0,[vdpptr,#vdpCounter]
	str r0,[vdpptr,#vdpLineIRQ]
	blmi VDPSetHIRQ				;@ Scanline bit
borderScanlineHook:
	mov r0,#0
	ldmfd sp!,{pc}

frameEndHook:
	mov r0,#0
	bl VDPSetScanline
	mov r0,#1
	ldmfd sp!,{pc}

;@----------------------------------------------------------------------------
SpriteParserM4:					;@ in r1 = scanline
;@----------------------------------------------------------------------------
	stmfd sp!,{r1,r3-r10}

	sub r1,r1,#1
	ldrb r10,[vdpptr,#vdpStat]
	ldr r9,[vdpptr,#VRAMPtr]
	ldrb r0,[vdpptr,#vdpSATOffset]
	and r0,r0,#0x7E
	add r9,r9,r0,lsl#7
	add r8,r9,#0x100

//	ldrb r11,[vdpptr,#vdpSPROffset]	;@ First or second half of VRAM for sprites?
//	and r11,r11,#4

	mov r3,#0x08					;@ Normal sprite height.
	ldrb r4,[vdpptr,#vdpMode2]
	movs r0,r4,lsl#31				;@ Double pixels/8x16 size
	movcs r3,#0x10					;@ 8x16 size
	movmi r3,r3,lsl#1				;@ Double size pixels

	add r5,vdpptr,#vdpSpritePosBuffer
	ldr r2,[vdpptr,#vdpSprStop]
	mov r6,#0
	mov r7,#-0x80
sp0Loop:
	ldrb r0,[r9],#1					;@ MasterSystem OBJ, r0=Ypos.
	cmp r0,r2
	beq sp0End
	subs r0,r1,r0
	cmppl r3,r0
	bhi sp0Add
sp0Chk:
	adds r7,r7,#2
	bne sp0Loop
sp0End:
	tst r4,#0x40					;@ Check if display is on and then check for collision.
	beq sc0End
	tst r10,#0x20					;@ Is collision already set?
	bne sc0End
sc1Loop:
	subs r6,r6,#1					;@ If there is only 1 sprite it can't collide with itself.
	ble sc0End
	mov r0,r6
	ldrb r3,[r5],#4
sc0Loop:
	subs r0,r0,#1
	bmi sc1Loop
	ldrb r2,[r5,r0,lsl#2]
	subs r2,r2,r3
	rsbmi r2,r2,#0
	movs r2,r2,lsr#3
	bne sc0Loop
									;@ Do pixel check here, Fantastic Dizzy needs it for "damage display".
	orr r10,r10,#0x20				;@ Collision flag.
sc0End:
	strb r10,[vdpptr,#vdpStat]
	ldmfd sp!,{r1,r3-r10}
	bx lr

sp0Add:
	cmp r6,#0x8						;@ This should be 4 in TMS9918 mode.
	ldrhmi r0,[r8,r7]				;@ MasterSystem OBJ, r0=Tile,Xpos.
	strmi r0,[r5,r6,lsl#2]

	addmi r6,r6,#1
	bmi sp0Chk
	orr r10,r10,#0x40				;@ Overflow flag ( >8 sprites on a line).
	b sp0End

;@----------------------------------------------------------------------------
VDPNewFrame:					;@ Called before line 0	(r0, r1 & r2 safe to use)
;@----------------------------------------------------------------------------
	stmfd sp!,{r3-r11,lr}
	bl transferVRAM
	ldmfd sp!,{r3-r11,lr}

	mov r0,#0
	str r0,[vdpptr,#vdpNametableLine]

	adr r0,defaultScanlineHook
	str r0,[vdpptr,#vdpScanlineHook]

	ldrb r0,[vdpptr,#vdpCounter]
	str r0,[vdpptr,#vdpLineIRQ]
	ldrb r0,[vdpptr,#vdpYScroll]
	strb r0,[vdpptr,#vdpYScrollBak1]

	ldrb r0,[vdpptr,#vdpRealMode]
	cmp r0,#VDPMODE_4
	bmi mode03_newframe

	ldrb r0,[vdpptr,#vdpMode1]
	ands r0,r0,#0x40
	movne r0,#15					;@ 16 topmost lines frozen.
	str r0,[vdpptr,#vdpScrollXLine]

	add r0,vdpptr,#scrollBuff
	ldrb r1,[vdpptr,#vdpXScroll]
	rsb r1,r1,#0
	strbeq r1,[r0]
	ldrne r1,=0x00000000
	movne r2,#16/4
	bne memset_

	bx lr
;@-------------------------------------------------------------------------------
mode03_newframe:
;@-------------------------------------------------------------------------------
	mov r0,#191
	str r0,[vdpptr,#vdpScrollXLine]

	mov r0,#0
	strb r0,[vdpptr,#vdpYScrollBak1]
	add r0,vdpptr,#scrollBuff
	mov r1,#192/4
	b memclr_

;@----------------------------------------------------------------------------
midFrame:							;@ Called at line 96
;@----------------------------------------------------------------------------
	stmfd sp!,{r3-r9,r11,lr}

	stmfd sp!,{vdpptr}
	bl paletteTxAll
	ldmfd sp!,{vdpptr}

	ldrb r0,[vdpptr,#vdpMode2]
	strb r0,[vdpptr,#vdpMode2Bak1]		;@ Screen on/off

	ldrb r0,[vdpptr,#vdpPGOffset]
	strb r0,[vdpptr,#vdpPGOffsetBak1]	;@ Pattern offset

	ldrb r0,[vdpptr,#vdpCalcMode]
	strb r0,[vdpptr,#vdpHeightMode]
	and r0,r0,#VDPMODE_MASK
	strb r0,[vdpptr,#vdpRealMode]

	ldmfd sp!,{r3-r9,r11,pc}
;@----------------------------------------
startVbl:							;@ 192/224/240
	eatcycles 1							;@ VBlank is 1 cycle before HBlank
	ldrb r0,[vdpptr,#vdpHCountBP]		;@ This is so that the vbl-bit can be read before the int happens
	sub r0,r0,#1
	strb r0,[vdpptr,#vdpHCountOffset]	;@ HC Latch need to be tweaked for this scanline.

	mov r0,#0x80						;@ Prime VBlank bit
	strb r0,[vdpptr,#vdpPrimedVBl]
	bx lr

;@----------------------------------------
VBL_Hook:							;@ 193/225/241
	add cycles,cycles,#1*CYCLE
	ldrb r0,[vdpptr,#vdpHCountBP]
	strb r0,[vdpptr,#vdpHCountOffset]	;@ HC Latch need to be reset for the rest of the scanlines.
	adr r0,borderScanlineHook
	str r0,[vdpptr,#vdpScanlineHook]

	ldrb r2,[vdpptr,#vdpPrimedVBl]
	strb rclr,[vdpptr,#vdpPrimedVBl]	;@ Clear byte.
	ldrb r0,[vdpptr,#vdpStat]
	orr r0,r0,r2						;@ VBlank bit
	strb r0,[vdpptr,#vdpStat]
	b VDPCheckIRQ

;@----------------------------------------
secondLastScanline:					;@ 261/312
	add cycles,cycles,#1*CYCLE			;@ 'Pause' IRQ is 1 cycle after HBlank
	ldrb r0,[vdpptr,#vdpHCountBP]
	add r0,r0,#1
	strb r0,[vdpptr,#vdpHCountOffset]	;@ HC Latch need to be reset for the rest of the scanlines.
	bx lr

;@----------------------------------------
lastScanline:						;@ 262/313
	eatcycles 1
	ldrb r0,[vdpptr,#vdpHCountBP]
	strb r0,[vdpptr,#vdpHCountOffset]	;@ HC Latch need to be reset for the rest of the scanlines.

	ldrb r0,[vdpptr,#vdpDebouncePin]
	ldr r1,[vdpptr,#debounceRoutine]	;@ Set IRQ/NMI pin on CPU
	cmp r1,#0
	bxne r1
	bx lr


;@----------------------------------------------------------------------------
VDPSetHIRQ:
;@----------------------------------------------------------------------------
	mov r0,#0x40						;@ Scanline bit
	strb r0,[vdpptr,#vdpPending]
;@----------------------------------------------------------------------------
VDPCheckIRQ:
;@----------------------------------------------------------------------------
	ldrb r2,[vdpptr,#vdpMode2]
	ldrb r0,[vdpptr,#vdpStat]
	and r0,r0,#0x80
	ands r0,r0,r2,lsl#2

	ldrbeq r2,[vdpptr,#vdpMode1]
	ldrbeq r0,[vdpptr,#vdpPending]
	andseq r0,r0,r2,lsl#2

	ldr r2,[vdpptr,#irqRoutine]			;@ Set IRQ/NMI pin on CPU
	bx r2

;@-------------------------------------------------------------------------------
VDPLatchHCounter:					;@ 228cpu=684master, r0 & r2 free to use.
;@-------------------------------------------------------------------------------
;@	mov r11,r11							;@ No$GBA breakpoint
	ldrb r0,[vdpptr,#vdpHCountOffset]	;@ 27/26 cycles.
	rsbs r0,r0,cycles,asr#CYC_SHIFT		;@ Tweak for OUT instruction taking some cycles before writing value to port.
	addmi r0,r0,#228
	add r0,r0,r0,lsl#1					;@ cycle*3
	rsb r0,r0,#600						;@ hc=(0xE9->0x93)
	sub r0,r0,#10
	mov r0,r0,asr#2
	strb r0,[vdpptr,#vdpHCountLatch]
	bx lr
;@----------------------------------------------------------------------------
VDPSetMode:
;@----------------------------------------------------------------------------
	ldrb r0,[vdpptr,#vdpMode1]
	ldrb r1,[vdpptr,#vdpMode2]
	mov r0,r0,lsr#1
	orr r0,r0,r1,lsl#27
	mov r0,r0,ror#2
	ldr r1,[vdpptr,#vdpModesPtr]
	ldrb r0,[r1,r0,lsr#27]
	strb r0,[vdpptr,#vdpCalcMode]

	ldrb r1,[vdpptr,#vdpTVType]
	tst r1,#TVTYPEPAL
	mov r1,#0xDA
	addne r1,r1,#0x18					;@ NTSC/PAL diff

	ands r0,r0,#VDPMODE_HEIGHTMASK		;@ 224 and/or 240 height
	addne r1,r1,#0x10
	str r1,[vdpptr,#vdpScanlineBP]
	mov r1,#208							;@ Sprite stop pos.
	movne r1,#0x200
	str r1,[vdpptr,#vdpSprStop]

	moveq r1,#32						;@ Maxpan
	movne r1,#64
	add r0,r1,#192						;@ 224/256
	str r0,[vdpptr,#vdpScrollMask]
	sub r0,r0,#32
	str r0,[vdpptr,#vdpVBlLine]
	add r0,r0,#1
	str r0,[vdpptr,#vdpVBlEndLine]
	ldrb r0,[vdpptr,#vdpNTMask]
	orreq r0,r0,#0x2
	bicne r0,r0,#0x2
	strb r0,[vdpptr,#vdpNTMask]

	ldrb r0,[vdpptr,#vdpGGMode]
	tst r0,#GGMODE

	movne r0,#152
	addne r0,r0,r1,lsr#1
	addeq r0,r1,#160
	str r0,[vdpptr,#vdpEndFrameLine]

	mov r0,#0
	movne r0,r1,lsr#1
	addne r0,r0,#8
	strb r0,[vdpptr,#vdpScrStartLine]

	b VDPCheckIRQ
;@----------------------------------------------------------------------------
VDPStatR:
;@----------------------------------------------------------------------------
;@	mov r11,r11							;@ No$GBA breakpoint
	stmfd sp!,{vdpptr,lr}
	mov r0,#0
	ldr r1,[vdpptr,#irqRoutine]			;@ Clear IRQ/NMI pin on CPU
	blx r1
	ldmfd sp!,{vdpptr,lr}
	strb rclr,[vdpptr,#vdpToggle]
	ldrb r0,[vdpptr,#vdpStat]
	orr r0,r0,#0x02						;@ PGA Tour Golf expects "something" in the low 5 bits
	strb rclr,[vdpptr,#vdpStat]
	strb rclr,[vdpptr,#vdpPending]
	ldrb r1,[vdpptr,#vdpPrimedVBl]
	cmp r1,#0
	bxeq lr

	cmp cycles,#11*CYCLE
	orrmi r0,r0,#0x80
	strbmi rclr,[vdpptr,#vdpPrimedVBl]
	bx lr
;@----------------------------------------------------------------------------
VDPVCounterR:
;@----------------------------------------------------------------------------
;@	mov r11,r11							;@ No$GBA breakpoint
	ldr r0,[vdpptr,#vdpScanline]
	ldrb r1,[vdpptr,#vdpVCountBP]
	cmp cycles,r1,lsl#CYC_SHIFT
	addcc r0,r0,#1						;@ Unsigned lower
	ldr r1,[vdpptr,#vdpScanlineBP]
	cmp r0,r1
	ldrhi r1,[vdpptr,#vdpTotalScanlines]
	subhi r0,r0,r1
	bx lr
;@----------------------------------------------------------------------------
VDPHCounterR:
;@----------------------------------------------------------------------------
	ldrb r0,[vdpptr,#vdpHCountLatch]
	bx lr


;@----------------------------------------------------------------------------
VDPCtrlMDW:
;@----------------------------------------------------------------------------
	ldrb r1,[vdpptr,#vdpToggle]
	eors r1,r1,#1
	strb r1,[vdpptr,#vdpToggle]

	strbne r0,[vdpptr,#vdpBuffMD]
	bxne lr
	and r0,r0,#0xFF
	ldrb r1,[vdpptr,#vdpBuffMD]
	orr r2,r1,r0,lsl#8
	ldr r1,[vdpptr,#vdpAdr]
	mov r1,r1,lsl#14
	mov r1,r1,lsr#14
	orr r1,r1,r2,lsl#18
	str r1,[vdpptr,#vdpAdr]

	ldrb r2,[vdpptr,#vdpRealMode]
	cmp r2,#VDPMODE_5
	bne vdpCtrlBW
	mov r2,r0,lsr#6
	cmp r2,#2
	ldrbne r2,[vdpptr,#vdpToggle]
	eorne r2,r2,#2
	strbne r2,[vdpptr,#vdpToggle]

	b vdpCtrlBW

;@----------------------------------------------------------------------------
VDPCtrlW:
;@----------------------------------------------------------------------------
	ldrb r1,[vdpptr,#vdpToggle]
	eors r1,r1,#1
	strb r1,[vdpptr,#vdpToggle]

	and r0,r0,#0xFF
	ldr r1,[vdpptr,#vdpAdr]
	biceq r1,r1,#0xFC000000
	bicne r1,r1,#0x03FC0000
	orreq r1,r1,r0,lsl#26
	orrne r1,r1,r0,lsl#18
	str r1,[vdpptr,#vdpAdr]
	bxne lr
vdpCtrlBW:
	movs r0,r0,lsr#6
	add r2,vdpptr,#vdpCtrlTable
	strb r0,[vdpptr,#vdpCtrl]
	ldr pc,[r2,r0,lsl#2]
;@----------------------------------------------------------------------------
VDPDataR:
;@----------------------------------------------------------------------------
	ldrb r0,[vdpptr,#vdpBuff]
	ldr r1,[vdpptr,#vdpAdr]
;@----------------------------------------------------------------------------
VDPctrl0W:							;@ Set read address, fill buffer.
;@----------------------------------------------------------------------------
	add r2,r1,#0x00040000
	str r2,[vdpptr,#vdpAdr]
	ldr r2,[vdpptr,#VRAMPtr]
	ldrb r1,[r2,r1,lsr#18]
	str r1,[vdpptr,#vdpBuff]			;@ Write to vdpbuffer and clear vdptoggle.
VDPctrl1W:								;@ Set VRAM write adress
VDPctrl3W:								;@ Set CRAM write adress
	bx lr
;@----------------------------------------------------------------------------
VDPctrl2W:							;@ Write to vdp registers.
;@----------------------------------------------------------------------------
	mov r1,r1,lsr#18
	and r0,r1,#0x1F00
	add r2,vdpptr,#vdpJumpTable
	ldr pc,[r2,r0,lsr#6]

;@----------------------------------------------------------------------------
VDPReg00W:
;@----------------------------------------------------------------------------
	strb r1,[vdpptr,#vdpMode1]
	b VDPSetMode
;@----------------------------------------------------------------------------
VDPReg01MDW:
;@----------------------------------------------------------------------------
	and r1,r1,#0xFE						;@ Mask out zoomed sprites on MD.
;@----------------------------------------------------------------------------
VDPReg01W:
;@----------------------------------------------------------------------------
	strb r1,[vdpptr,#vdpMode2]
	b VDPSetMode
;@----------------------------------------------------------------------------
VDPReg02W:
;@----------------------------------------------------------------------------
	ldrb r0,[vdpptr,#vdpNameTable]
	strb r1,[vdpptr,#vdpNameTable]

	ldr r2,[vdpptr,#vdpScanline]		;@ r2=scanline
ntFinnish:
	cmp r2,#224
	movhi r2,#224
	ldr r1,[vdpptr,#vdpNametableLine]
	str r2,[vdpptr,#vdpNametableLine]
	sub r1,r1,r2

	add r2,r2,vdpptr
	add r2,r2,#TMapBuff
nt1:
	strb r0,[r2],#-1					;@ Fill backwards from scanline to lastline
	adds r1,r1,#1
	ble nt1
	bx lr

;@----------------------------------------------------------------------------
VDPReg03W:							;@ Color Table - offset
;@----------------------------------------------------------------------------
	ldrb r0,[vdpptr,#vdpCTOffset]
	strb r1,[vdpptr,#vdpCTOffset]
	eor r0,r0,r1
	ands r0,r0,#0x80
	bxeq lr
DT_clear:
	and r1,r1,#0x80
	add r0,vdpptr,#dirtyTiles
	add r0,r0,r1,lsl#1
	mov r1,#0x40
	b memclr_
;@----------------------------------------------------------------------------
VDPReg04W:							;@ Pattern Generator Table - offset
;@----------------------------------------------------------------------------
	and r1,r1,#7
	ldrb r0,[vdpptr,#vdpPGOffset]
	strb r1,[vdpptr,#vdpPGOffset]
	eor r0,r0,r1
	ands r0,r0,#4
	bxeq lr
	mov r1,r1,lsl#5
	b DT_clear
;@----------------------------------------------------------------------------
VDPReg05W:							;@ Sprite Attribute Table - offset
;@----------------------------------------------------------------------------
	strb r1,[vdpptr,#vdpSATOffset]
	bx lr
;@----------------------------------------------------------------------------
VDPReg06W:							;@ Sprite tiles - offset
;@----------------------------------------------------------------------------
	and r1,r1,#7
	ldrb r0,[vdpptr,#vdpSPROffset]
	strb r1,[vdpptr,#vdpSPROffset]
	cmp r0,r1
	bxeq lr

	add r0,vdpptr,#dirtyTiles
	add r0,r0,r1,lsl#6
	mov r1,#0x10
	b memclr_
;@----------------------------------------------------------------------------
VDPReg07W:							;@ Backdrop Color
;@----------------------------------------------------------------------------
	strb r1,[vdpptr,#vdpBDColor]
	bx lr
;@----------------------------------------------------------------------------
VDPReg08W:							;@ Horizontal Scroll register
;@----------------------------------------------------------------------------
	ldrb r0,[vdpptr,#vdpXScroll]
	strb r1,[vdpptr,#vdpXScroll]
	rsb r0,r0,#0

	rsbs r2,cycles,#12*CYCLE
	ldr r2,[vdpptr,#vdpScanline]		;@ r2=scanline
	adc r2,r2,#0						;@ Also add carry if cycles < 11
	cmp r2,#225
	movhi r2,#225
	ldr r1,[vdpptr,#vdpScrollXLine]
	subs r1,r1,r2
	strmi r2,[vdpptr,#vdpScrollXLine]

	add r2,r2,vdpptr
	add r2,r2,#scrollBuff
sx1:
	adds r1,r1,#1
	strble r0,[r2],#-1					;@ Fill backwards from scanline to lastline
	bmi sx1
	bx lr

;@----------------------------------------------------------------------------
VDPReg09W:							;@ Vertical Scroll register
;@----------------------------------------------------------------------------
	strb r1,[vdpptr,#vdpYScroll]
	bx lr
;@----------------------------------------------------------------------------
VDPReg0AW:							;@ HBlank counter value
;@----------------------------------------------------------------------------
	strb r1,[vdpptr,#vdpCounter]
;@	bx lr
;@----------------------------------------------------------------------------
;@VDPReg0BW:						;@ MD, Mode Set Register No. 3
;@----------------------------------------------------------------------------
;@	bx lr
;@----------------------------------------------------------------------------
;@VDPReg0CW:						;@ MD, Mode Set Register No. 4
;@----------------------------------------------------------------------------
;@	bx lr
;@----------------------------------------------------------------------------
;@VDPReg0DW:						;@ MD, H Scroll Data Table Base Address
;@----------------------------------------------------------------------------
;@	bx lr
;@----------------------------------------------------------------------------
VDPReg0FW:							;@ MD, Auto Increment Data
;@----------------------------------------------------------------------------
	bx lr
;@----------------------------------------------------------------------------
;@VDPReg10W:						;@ MD, H Scroll Data Table Base Address
;@----------------------------------------------------------------------------
;@	bx lr
;@----------------------------------------------------------------------------



;@----------------------------------------------------------------------------
VDPDataSMSW:
;@----------------------------------------------------------------------------
	ldr r1,[vdpptr,#vdpAdr]
	add r2,r1,#0x00040000
	str r2,[vdpptr,#vdpAdr]
	str r0,[vdpptr,#vdpBuff]			;@ Write to vdpbuffer and clear vdptoggle.

	ldrb r2,[vdpptr,#vdpCtrl]
	cmp r2,#0x03
	beq CRAMW
;@----------------------------------------------------------------------------
VRAMW:
;@----------------------------------------------------------------------------
	ldr r2,[vdpptr,#VRAMPtr]
	strb r0,[r2,r1,lsr#18]
	strb rclr,[vdpptr,r1,lsr#23]		;@ Dirty tiles
	bx lr
;@----------------------------------------------------------------------------
CRAMW:
;@----------------------------------------------------------------------------
	and r0,r0,#0x3F
	orr r2,r0,r0,lsl#4
	bic r2,r2,#0xFC
	and r0,r0,#0x0C
	orr r0,r2,r0,lsl#2
	orr r0,r0,r0,lsl#2

	movs r1,r1,lsr#18
	b WritePal

;@----------------------------------------------------------------------------
VDPDataGGW:
;@----------------------------------------------------------------------------
	ldrb r2,[vdpptr,#vdpCtrl]
	cmp r2,#0x03
	ldr r1,[vdpptr,#vdpAdr]
	add r2,r1,#0x00040000
	str r2,[vdpptr,#vdpAdr]
	ldrbeq r2,[vdpptr,#vdpBuff]
	str r0,[vdpptr,#vdpBuff]			;@ Write to vdpbuffer and clear vdptoggle.

	bne VRAMW
;@----------------------------------------------------------------------------
CRAMGGW:
;@----------------------------------------------------------------------------
	movs r1,r1,lsr#19
	bxcc lr

	and r0,r0,#0x0F
	orr r0,r2,r0,lsl#8
WritePal:
	and r1,r1,#0x1F
	add r2,vdpptr,#vdpPaletteRAM
	add r2,r2,r1,lsl#1
	strh r0,[r2]
	bx lr

;@----------------------------------------------------------------------------
VDPDataMDW:
;@----------------------------------------------------------------------------
	ldr r1,[vdpptr,#vdpAdr]
	add r2,r1,#0x00040000
	str r2,[vdpptr,#vdpAdr]
	strb rclr,[vdpptr,#vdpToggle]		;@ MD doesn't touch the vdpBuff on write

	ldrb r2,[vdpptr,#vdpCtrl]
	tst r2,#0x02
	beq VRAMW
;@----------------------------------------------------------------------------
CRAMMDW:
;@----------------------------------------------------------------------------
	ldrb r2,[vdpptr,#vdpRealMode]
	cmp r2,#VDPMODE_5
	bne CRAMW

	ldrb r2,[vdpptr,#vdpBuff]
	str r0,[vdpptr,#vdpBuff]			;@ Write to vdpbuffer and clear vdptoggle.

	movs r1,r1,lsr#19
	bxcc lr

	and r0,r0,#0x0F
	orr r0,r2,r0,lsl#8
	bic r2,r0,#0x0770
	orr r0,r0,r2,lsr#3

WritePalMD:
	stmfd sp!,{r3,r4}
	and r1,r1,#0x3F
	add r2,vdpptr,#vdpPaletteRAM
	add r2,r2,r1,lsl#1
	strh r0,[r2]
//	ldr r4,=MAPPED_RGB
//	mov r3,r0,lsl#1
//	ldrh r3,[r4,r3]
//	ldr r2,=EMUPALBUFF+0x100
	add r2,r2,r1,lsl#1
//	strh r3,[r2,#0x80]					;@ bgtile palette high prio

	bic r0,r0,#0x0110
	bic r0,r0,#0x0001
	ldrh r0,[r4,r0]
	strh r0,[r2]						;@ bgtile palette low prio
	ldmfd sp!,{r3,r4}

	bx lr
;@----------------------------------------------------------------------------
VDPDataTMSW:
;@----------------------------------------------------------------------------
	ldr r1,[vdpptr,#vdpAdr]
	add r2,r1,#0x00040000
	str r2,[vdpptr,#vdpAdr]
	str r0,[vdpptr,#vdpBuff]			;@ Write to vdpbuffer and clear vdptoggle.
	b VRAMW

;@----------------------------------------------------------------------------
	.end
#endif // #ifdef __arm__
