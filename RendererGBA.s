#ifdef __arm__
#if defined(GBA) || defined(NDS)

#include "SegaVDP.i"

#ifdef GBA
#include "../Shared/gba_asm.h"
	.equ CHRDecode, BG_GFX+0x4400			;@ 0x400
#else
#include "../Shared/nds_asm.h"
#endif

	.global CHRDecode

	.global rendererInit
	.global bgFinish
	.global transferVRAM
	.global earlyFrame

	.syntax unified
	.arm

	.section .text
	.align 2

;@----------------------------------------------------------------------------
rendererInit:				;@ (called from gfxInit) only need to call once
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}

	ldr r0,=BG_GFX+0x4000
	mov r1,#0x4000
	bl memclr_					;@ Clear NDS VRAM
	add r0,r0,#0x80
	ldr r1,=0x20202020
	mov r2,#0x10
	bl memset_					;@ BGR color 0
	add r0,r0,#0x40
	ldr r1,=0x30303030
	mov r2,#0x10
	bl memset_					;@ BGR color 1

	ldr r0,=CHRDecode			;@ Destination
	mov r1,#0xffffff00			;@ Build chr decode tbl
ppi:
	movs r2,r1,lsl#31
	movne r2,#0x10000000
	orrcs r2,r2,#0x01000000
	tst r1,r1,lsl#29
	orrmi r2,r2,#0x00100000
	orrcs r2,r2,#0x00010000
	tst r1,r1,lsl#27
	orrmi r2,r2,#0x00001000
	orrcs r2,r2,#0x00000100
	tst r1,r1,lsl#25
	orrmi r2,r2,#0x00000010
	orrcs r2,r2,#0x00000001
	str r2,[r0],#4
	adds r1,r1,#1
	bne ppi

	bl setupScaling
	bl VDP0ApplyScaling
	ldmfd sp!,{lr}
	bx lr

#ifdef GBA
	.section .ewram, "ax", %progbits	;@ For the GBA
#else
	.section .text						;@ For anything else
#endif
	.align 2
;@------------------------------------------------------------------------------
earlyFrame:					;@ Called at line 0,16 or 32	(r0,r2 safe to use)
;@------------------------------------------------------------------------------
	stmfd sp!,{r1,r3-r12,lr}

	ldrb r0,[vdpptr,#vdpSprScan]
	cmp r0,#0
	ldreq r0,=defaultScanlineHook
	ldrne r0,=spriteScanner
	str r0,[vdpptr,#vdpScanlineHook]
	adrne lr,earlyFrameEnd
	bne spriteScannerStart

	ldrb r0,[vdpptr,#vdpRealMode]
	cmp r0,#VDPMODE_4
	bleq sprDMADo0
earlyFrameEnd:
	ldmfd sp!,{r1,r3-r12,pc}

;@----------------------------------------------------------------------------
transferVRAM:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	ldr r5,[vdpptr,#VRAMPtr]
	ldr r6,=CHRDecode
	ldr r7,[vdpptr,#vdpBgrTileOfs]
	ldr r8,[vdpptr,#vdpSprTileOfs]

	ldrb r0,[vdpptr,#vdpRealMode]
	cmp r0,#VDPMODE_4
	beq transferVRAM_m4
	cmp r0,#VDPMODE_5
	beq transferVRAM_m5
	ldrb r2,[vdpptr,#vdpMode2]
	tst r2,#0x40				;@ Screen on?
	ldmfdeq sp!,{pc}
	ldr r8,=0x11111111
	ldrb r1,[vdpptr,#vdpPGOffsetBak1]
	ldrb r3,[vdpptr,#vdpCTOffset]
	mov r1,r1,lsl#6
	cmp r0,#VDPMODE_2
	beq	transferVRAM_m2
	cmp r0,#VDPMODE_0
	beq	transferVRAM_m0
	cmp r0,#VDPMODE_1
	beq	transferVRAM_m1
	cmp r0,#VDPMODE_3
	beq	transferVRAM_m3
	ldmfd sp!,{pc}

;@----------------------------------------------------------------------------
transferVRAM_m0:
;@----------------------------------------------------------------------------
	and r1,r1,#0x1C0
	add r11,r5,r3,lsl#6
	sub r11,r11,r1,lsr#1
	ldrb r9,[vdpptr,r3,lsl#1]
	orr r0,r9,#0x01
	strb r0,[vdpptr,r3,lsl#1]
	orr r9,r9,r9,lsl#8
	orr r9,r9,r9,lsl#16
	sub r7,r7,r1,lsl#7
tileLoop0_0:
	ldr r0,=0x01010101			;@ Dirtytiles mode 0 bgr.
	ldr r10,[vdpptr,r1]			;@ DirtyTiles are first in VDP struct
	orr r2,r10,r0
	str r2,[vdpptr,r1]
	and r10,r10,r9
	tst r10,#0x00000001
	bleq tileLoop0_1
	add r1,r1,#1
	tst r10,#0x00000100
	bleq tileLoop0_1
	add r1,r1,#1
	tst r10,#0x00010000
	bleq tileLoop0_1
	add r1,r1,#1
	tst r10,#0x01000000
	bleq tileLoop0_1
	add r1,r1,#1
	tst r1,#0x3F
	bne tileLoop0_0

	sub r1,r1,#0x40
	add r7,r7,r1,lsl#7
	b tileLoopSpr
;@----------------------------------------------------------------------------
transferVRAM_m1:
;@----------------------------------------------------------------------------
	and r1,r1,#0x1C0
	sub r7,r7,r1,lsl#7
	ldr r9,=0x02020202			;@ Dirtytiles mode 1 bgr.
tileLoop1_0:
	ldr r10,[vdpptr,r1]			;@ DirtyTiles are first in VDP struct
	orr r2,r10,r9
	str r2,[vdpptr,r1]
	tst r10,#0x00000002
	bleq tileLoop1_1
	add r1,r1,#1
	tst r10,#0x00000200
	bleq tileLoop1_1
	add r1,r1,#1
	tst r10,#0x00020000
	bleq tileLoop1_1
	add r1,r1,#1
	tst r10,#0x02000000
	bleq tileLoop1_1
	add r1,r1,#1
	tst r1,#0x3F
	bne tileLoop1_0

	ldmfd sp!,{pc}

;@----------------------------------------------------------------------------
transferVRAM_m2:
;@----------------------------------------------------------------------------
	and r1,r1,#0x100
	and r3,r3,#0x80
	add r11,r5,r3,lsl#6
	sub r11,r11,r1,lsl#5
	add r4,vdpptr,r3,lsl#1
	sub r7,r7,r1,lsl#7
	ldr r9,=0x04040404			;@ Dirtytiles mode 2 bgr.
tileLoop2_0:
	ldr r10,[vdpptr,r1]			;@ DirtyTiles are first in VDP struct
	orr r2,r10,r9
	str r2,[vdpptr,r1]
	ldr r2,[r4]
	and r10,r10,r2
	orr r2,r2,r9
	str r2,[r4],#4
	tst r10,#0x00000004
	bleq tileLoop2_2
	add r1,r1,#1
	tst r10,#0x00000400
	bleq tileLoop2_2
	add r1,r1,#1
	tst r10,#0x00040000
	bleq tileLoop2_2
	add r1,r1,#1
	tst r10,#0x04000000
	bleq tileLoop2_2
	add r1,r1,#1
	tst r1,#0x3F
	bne tileLoop2_0
	and r0,r1,#0xC0
	cmp r0,#0xC0
	bne tileLoop2_0

	sub r1,r1,#0xC0
	add r7,r7,r1,lsl#7
	b tileLoopSpr
;@----------------------------------------------------------------------------
transferVRAM_m3:
;@----------------------------------------------------------------------------
	and r1,r1,#0x1C0
	ldr r9,=0x08080808			;@ Dirtytiles mode 3 bgr.
	sub r7,r7,r1,lsl#9
tileLoop3_0:
	ldr r10,[vdpptr,r1]			;@ DirtyTiles are first in VDP struct
	orr r2,r10,r9
	str r2,[vdpptr,r1]
	tst r10,#0x00000008
	bleq tileLoop3_1
	add r1,r1,#1
	tst r10,#0x00000800
	bleq tileLoop3_1
	add r1,r1,#1
	tst r10,#0x00080000
	bleq tileLoop3_1
	add r1,r1,#1
	tst r10,#0x08000000
	bleq tileLoop3_1
	add r1,r1,#1
	tst r1,#0x3F
	bne tileLoop3_0

;@----------------------------------------------------------------------------
tileLoopSpr:				;@ Mode0, 2 & 3 sprites.
;@----------------------------------------------------------------------------
	ldr r7,[vdpptr,#vdpSprTileOfs]
	add r7,r7,#0x2000			;@ Sprites @ 0x06016000/0x06402000
	ldrb r1,[vdpptr,#vdpSPROffset]
	ldr r5,[vdpptr,#VRAMPtr]
	ldr r9,=0x10101010			;@ Dirtytiles mode 0, 2 & 3 spr.
	and r1,r1,#0x07
	mov r1,r1,lsl#6
	sub r7,r7,r1,lsl#7
tileLoop2_1:
	ldr r10,[vdpptr,r1]			;@ DirtyTiles are first in VDP struct
	orr r2,r10,r9
	str r2,[vdpptr,r1]
	tst r10,#0x00000010
	bleq tileLoop1_1
	add r1,r1,#1
	tst r10,#0x00001000
	bleq tileLoop1_1
	add r1,r1,#1
	tst r10,#0x00100000
	bleq tileLoop1_1
	add r1,r1,#1
	tst r10,#0x10000000
	bleq tileLoop1_1
	add r1,r1,#1
	tst r1,#0x3F
	bne tileLoop2_1

	ldmfd sp!,{pc}

;@----------------------------------------------------------------------------
;@----------------------------------------------------------------------------
tileLoop0_1:
	ldrb r2,[r11,r1,lsr#1]
	mov r3,r2,lsr#4
	and r2,r2,#0x0F
tileLoop0_2:
	ldrb r0,[r5,r1,ror#32-5]
	ldr r0,[r6,r0,lsl#2]
	mul r4,r3,r0
	eors r0,r0,r8
	mlane r4,r2,r0,r4
	str r4,[r7,r1,ror#32-7]
	adds r1,r1,#0x08000000
	bcc tileLoop0_2
	bx lr

tileLoop1_1:
	ldrb r0,[r5,r1,ror#32-5]
	ldr r0,[r6,r0,lsl#2]
	str r0,[r7,r1,ror#32-7]
	adds r1,r1,#0x08000000
	bcc tileLoop1_1
	bx lr

tileLoop2_2:
	ldrb r2,[r11,r1,ror#32-5]
	ldrb r0,[r5,r1,ror#32-5]
	ldr r0,[r6,r0,lsl#2]
	movs r3,r2,lsr#4
	mulne r3,r0,r3
	eors r0,r0,r8
	andnes r2,r2,#0x0F
	mlane r3,r2,r0,r3
	str r3,[r7,r1,ror#32-7]
	adds r1,r1,#0x08000000
	bcc tileLoop2_2
	bx lr

tileLoop3_1:
	add r11,r7,r1,ror#32-9
tileLoop3_2:
	ldrb r0,[r5,r1,ror#32-5]
	mov r0,r0,ror#4
	orr r0,r0,r0,lsr#12
	orr r0,r0,r0,lsl#4
	orr r0,r0,r0,lsl#8
	str r0,[r11],#4
	str r0,[r11],#4
	str r0,[r11],#4
	str r0,[r11],#4
	adds r1,r1,#0x08000000
	bcc tileLoop3_2
	bx lr

;@----------------------------------------------------------------------------
transferVRAM_m5:
;@----------------------------------------------------------------------------
	ldr r9,=0x40404040			;@ Dirtytiles mode5 bgr & spr
	mov r1,#0
tileLoop5_0:
	ldr r10,[vdpptr,r1]
	str r9,[vdpptr,r1]
	tst r10,#0x00000040
	bleq tileLoop5_1
	add r1,r1,#1
	tst r10,#0x00004000
	bleq tileLoop5_1
	add r1,r1,#1
	tst r10,#0x00400000
	bleq tileLoop5_1
	add r1,r1,#1
	tst r10,#0x40000000
	bleq tileLoop5_1
	add r1,r1,#1
	cmp r1,#0x200
	bne tileLoop5_0

	ldmfd sp!,{pc}

tileLoop5_1:
	ldr r0,[r5,r1,ror#32-5]
	str r0,[r7,r1,ror#32-5]
	str r0,[r8,r1,ror#32-5]
	adds r1,r1,#0x20000000
	bcc tileLoop5_1

	bx lr

#ifdef NDS
	.section .itcm, "ax", %progbits		;@ For the NDS ARM9
#elif GBA
	.section .iwram, "ax", %progbits	;@ For the GBA
#else
	.section .text						;@ For everything else
#endif
	.align 2
;@----------------------------------------------------------------------------
transferVRAM_m4:
;@----------------------------------------------------------------------------
	ldr r9,=0x20202020			;@ Dirtytiles mode4 bgr & spr
	mov r1,#0x200
tl4pre:
	subs r1,r1,#4
	ldmfdmi sp!,{pc}
tileLoop4_0:
	ldr r10,[vdpptr,r1]
	bics r2,r9,r10
	beq tl4pre
	orr r2,r10,r9
	str r2,[vdpptr,r1]
	tst r10,#0x00000020
	bleq tileLoop4_1
	add r1,r1,#1
	tst r10,#0x00002000
	bleq tileLoop4_1
	add r1,r1,#1
	tst r10,#0x00200000
	bleq tileLoop4_1
	add r1,r1,#1
	tst r10,#0x20000000
	bleq tileLoop4_1
	subs r1,r1,#7
	bpl tileLoop4_0

	ldmfd sp!,{pc}

tileLoop4_1:
	ldr r0,[r5,r1,ror#32-5]

	ands r3,r0,#0x000000FF
	ldrne r3,[r6,r3,lsl#2]
	ands r2,r0,#0x0000FF00
	ldrne r2,[r6,r2,lsr#6]
	orrne r3,r3,r2,lsl#1
	ands r2,r0,#0x00FF0000
	ldrne r2,[r6,r2,lsr#14]
	orrne r3,r3,r2,lsl#2
	ands r2,r0,#0xFF000000
	ldrne r2,[r6,r2,lsr#22]
	orrne r3,r3,r2,lsl#3

	str r3,[r7,r1,ror#32-5]
	str r3,[r8,r1,ror#32-5]
	adds r1,r1,#0x20000000
	bcc tileLoop4_1

	bx lr

;@----------------------------------------------------------------------------
;@	r0 = Destination address
;@	r1 = Source address
;@	r2 = Tile offset
;@	r3 = Row count
;@	ldr r4,=0x00010001
;@	ldr r5,=0xF000F000
;@	ldr r6,=0x000003FF
;@ MSB          LSB
;@ ---pcvhnnnnnnnnn
;@----------------------------------------------------------------------------
bgMode4:
bgM4Frame:
	subs r3,r3,#1
	ldmfdmi sp!,{r3-r11,pc}

	ldrb r11,[r8],#16
	ldrb r10,[vdpptr,#vdpNTMask]
	movs r10,r10,lsr#1
	orrcs r11,r11,#0x01
	ands r10,r10,r11,lsr#1
	orr r10,lr,r10,lsl#5
	biccc r10,r10,#0x10

//	ldr r9,=0x8080
//	mov r7,r10,lsl#1
//	ldrh r11,[vdpptr,r7]
//	orr r9,r9,r11
//	bics r11,r9,r11
//	addeq lr,lr,#1
//	beq bgM4Frame
//	strh r9,[vdpptr,r7]

	add r9,r1,r10,lsl#6
	add r7,r0,lr,lsl#6

	add lr,lr,#1
	ldr r10,[vdpptr,#vdpScrollMask]
	cmp lr,r10,lsr#3
	subpl lr,lr,r10,lsr#3

bgM4Row:
	ldr r10,[r9],#4				;@ Read from MasterSystem Tilemap RAM

	and r11,r4,r10,lsr#11
	orr r11,r11,r4,lsl#1			;@ Bgr color 0x30 & 0x40
	str r11,[r7,r4,lsr#4]		;@ Write to GBA/NDS Tilemap RAM, BGR color

	tst r4,r10,lsl#4			;@ Shift out top P bit, test low P bit.
	bic r10,r10,r5
	and r11,r10,r5,lsr#3
	add r10,r10,r11				;@ XY flip + color.

	add r10,r10,r2				;@ New tile offset
	str r10,[r7,#0x800]			;@ Write to GBA/NDS Tilemap RAM, behind sprites
	biccc r10,r10,r6,lsl#16
	biceq r10,r10,r6
	str r10,[r7],#4				;@ Write to GBA/NDS Tilemap RAM, in front of sprites
	tst r7,#0x3C				;@ 32 tiles wide
	bne bgM4Row
	b bgM4Frame

#ifdef GBA
	.section .ewram, "ax", %progbits	;@ For the GBA
#else
	.section .text						;@ For anything else
#endif
	.align 2
;@----------------------------------------------------------------------------
bgFinish:					;@ End of frame...
;@----------------------------------------------------------------------------
//	ldr r0,=fpsValue
//	ldrb r0,[r0]
//	tst r0,#0xf
//	bxne lr
	stmfd sp!,{r3-r11,lr}

	ldr r0,[vdpptr,#vdpBgrMapOfs0]
	mov r1,#BG_GFX
	add r0,r1,r0,lsl#3
	ldr r2,[vdpptr,#vdpBgrTileOfs]
	and r2,r2,#0x3FC0
	mov r2,r2,lsr#5
	orr r2,r2,r2,lsl#16
	ldr r4,=0x00010001
	ldr r5,=0xF000F000
	ldr r6,=0x000003FF
	ldrb lr,[vdpptr,#vdpYScrollBak1]
	and r10,lr,#7
	mov lr,lr,lsr#3
	rsbs r11,r10,#4
	movmi r11,#0
	add r8,vdpptr,#TMapBuff
	ldrb r11,[r8,r11,lsl#1]!
	ldrb r10,[vdpptr,#vdpHeightMode]
	cmp r10,#VDPMODE_4_224
	cmpne r10,#VDPMODE_4_240
	ldr r1,[vdpptr,#VRAMPtr]
	addeq r1,r1,#0x700
	mov r3,#28
	moveq r3,#32

	and r10,r10,#0x0F
	cmp r10,#VDPMODE_4
	beq bgMode4
	cmp r10,#VDPMODE_5
	beq bgMode5

	ldrb r7,[vdpptr,#vdpPGOffsetBak1]
	and r7,r7,#3
	eor r7,r7,#3
	orr r7,r7,r7,lsl#16
	mov r7,r7,lsl#8

	and r11,r11,#0xF
	add r1,r1,r11,lsl#10

	mov r5,#0
	mov r6,#0
	cmp r10,#VDPMODE_2
	moveq r6,r4,lsl#8			;@ 0x01000100
	cmpne r10,#VDPMODE_0
	beq bgMode02
	mov r3,#24
	cmp r10,#VDPMODE_3
	beq bgMode3
	cmp r10,#VDPMODE_1
	bne bgModeB
;@----------------------------------------------------------------------------
;@	r0 = Destination address
;@	r1 = Source address
;@	r2 = Tile offset
;@	r3 = Row count
;@	r4 = 0x00010001
;@	r5 = #0
;@----------------------------------------------------------------------------
bgMode1:
	orr r2,r2,r4,lsl#13			;@ Palette 2
bgM1Loop:
bgM1Row:
	ldrh r6,[r1],#2				;@ Read from MasterSystem Tilemap RAM
	orr r6,r6,r6,lsl#8
	bic r6,r6,#0xFF00
	add r6,r6,r2				;@ Palette & tileoffset

	str r5,[r0,r4,lsr#4]		;@ Write to GBA/NDS Tilemap RAM, BGR color
	str r6,[r0,#0x800]			;@ Write to GBA/NDS Tilemap RAM, behind sprites
	str r5,[r0],#4				;@ Write to GBA/NDS Tilemap RAM, in front of sprites
	adds r3,r3,#0x10000000		;@ 16
	bcc bgM1Row
	add r1,r1,#8				;@ 40 columns
	subs r3,r3,#1
	bne bgM1Loop
bgModeB:
	ldmfd sp!,{r3-r11,pc}

;@----------------------------------------------------------------------------
;@	r0 = Destination address
;@	r1 = Source address
;@	r2 = Tile offset
;@	r4 = 0x00010001
;@	r5 = #0
;@	r6 = 0x00010001/0x00000000
;@	r7 = 0x0M000M00
;@----------------------------------------------------------------------------
bgMode02:						;@ Mode 0 & 2
	orr r2,r2,r4,lsl#14			;@ Palette 4
	mov r3,#3
bgM2Loop2:
	bic r8,r2,r7				;@ r7=Inverted mask
bgM2Loop:
	ldrh r9,[r1],#2				;@ Read from MasterSystem Tilemap RAM
	orr r9,r9,r9,lsl#8
	bic r9,r9,#0xFF00
	add r9,r9,r8				;@ Palette & tile offset.

	str r5,[r0,r4,lsr#4]		;@ Write to GBA/NDS Tilemap RAM, BGR color
	str r9,[r0,#0x800]			;@ Write to GBA/NDS Tilemap RAM, behind sprites
	str r5,[r0],#4				;@ Write to GBA/NDS Tilemap RAM, in front of sprites
	adds r3,r3,#0x02000000		;@ 16*8
	bcc bgM2Loop
	add r2,r2,r6				;@ Add tileoffset for group.
	subs r3,r3,#1
	bne bgM2Loop2

	ldmfd sp!,{r3-r11,pc}

;@----------------------------------------------------------------------------
;@	r0 = Destination address
;@	r1 = Source address
;@	r2 = Tile offset
;@	r3 = Row count
;@	r4 = 0x00010001
;@	r5 = #0
;@----------------------------------------------------------------------------
bgMode3:
	orr r2,r2,r4,lsl#14			;@ Palette 4
bgM3Loop2:
	bic r2,r2,r4,lsl#2
bgM3Loop:
	ldrh r6,[r1],#2				;@ Read from MasterSystem Tilemap RAM
	orr r6,r6,r6,lsl#8
	bic r6,r6,#0xFF00
	add r6,r2,r6,lsl#2			;@ Palette & tile offset.

	str r5,[r0,r4,lsr#4]		;@ Write to GBA/NDS Tilemap RAM, BGR color
	str r6,[r0,#0x800]			;@ Write to GBA/NDS Tilemap RAM, behind sprites
	str r5,[r0],#4				;@ Write to GBA/NDS Tilemap RAM, in front of sprites
	adds r3,r3,#0x10000000		;@ 16
	bcc bgM3Loop
	add r2,r2,r4				;@ Add tileoffset for group.
	subs r3,r3,#1
	bne bgM3Loop2

	ldmfd sp!,{r3-r11,pc}

;@----------------------------------------------------------------------------
;@	r0 = Destination address
;@	r1 = Source address
;@	r2 = Tile offset
;@	r3 = Row count
;@	ldr r7,=0x00010001
;@	ldr r6,=0x000003FF
;@	lr = y scroll row
;@	r11 = VDPRAM
;@ MSB          LSB
;@ pccvhnnnnnnnnnnn
;@----------------------------------------------------------------------------
bgMode5:
	ldr r5,=0xFC00FC00
bgM5Loop:
	ldrb r6,[r8],#8
	and r6,r6,#0x08				;@ 0x2000, should be 0x1C
	orr r6,lr,r6,lsl#4
	add r9,r1,r6,lsl#6
	add r7,r0,lr,lsl#6

	add lr,lr,#1
;@	ldr r6,[vdpptr,#vdpScrollMask]
	mov r6,#256
	cmp lr,r6,lsr#3
	subpl lr,lr,r6,lsr#3

bgM5Row:
	ldr r6,[r9],#4				;@ Read from MegaDrive Tilemap RAM

	and r11,r4,r6,lsr#11
	str r11,[r7,r4,lsr#4]		;@ Write to GBA/NDS Tilemap RAM, BGR color

	bic r11,r6,r5
	and r6,r5,r6,lsr#1
	add r6,r6,r2				;@ Tile offset.
	orr r6,r6,r4,lsl#15			;@ MD palette
	orr r11,r11,r6				;@ XY flip + color.

	str r11,[r7,#0x800]			;@ Write to GBA/NDS Tilemap RAM, behind sprites
	mov r11,#0
	str r11,[r7],#4				;@ Write to GBA/NDS Tilemap RAM, in front of sprites
	tst r7,#0x3C				;@ 32 tiles wide
	bne bgM5Row
	subs r3,r3,#1
	bne bgM5Loop

	ldmfd sp!,{r3-r11,pc}
;@----------------------------------------------------------------------------
#ifdef NDS
	.section .bss
	.align 2
CHRDecode:
	.space 0x400
#endif
;@----------------------------------------------------------------------------
	.end
#endif // #ifdef GBA || NDS
#endif // #ifdef __arm__
