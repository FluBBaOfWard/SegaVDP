//
//  SegaVDP.h
//  Sega VDP chip emulator for GBA/NDS.
//
//  Created by Fredrik Ahlström on 2012-03-10.
//  Copyright © 2012-2026 Fredrik Ahlström. All rights reserved.
//

#ifndef SegaVDP_HEADER
#define SegaVDP_HEADER

/** Game screen width in pixels */
#define GAME_WIDTH  (256)

#define VDPSTATESIZE	(0xE0)

typedef struct {
	u8 *dirtyTiles[0x200];
	u8 spriteTileBuffer[0x20];
	u32 spritePosBuffer[8];
	void (*jumpTable[0x20])(void);
	u8 ctrlTable[0x10];
	/// Horizontal scrollbuffer/ Tilemap buffer.
	u8 scrollTMapBuff[320*2];
	u8 *VRAMPtr;
	u8 *VRAMCopyPtr;
	u8 *modesPtr;
	void (*irqRoutine)(bool state);
	void (*debounceRoutine)(bool state);
	u8 *scanlineHook;
	u8 *tmpOAMBuffer;
	u8 *dmaOAMBuffer;
	u8 *dirtyTilesPtr;
	u8 padding0[0x0C];

//vdpState:
	u32 vdpAdr;
	int scanline;
	/// vdpbuff + toggle need to be together in this way.
	u8 buff[2];
	u8 toggle[2];
	u8 buffMD;
	u8 ctrl;
	/// VBlank + spr stat
	u8 stat;
	/// Line interrupt pending
	u8 pending;

	u8 mode1;
	u8 mode2;
	u8 nameTable;
	u8 ctOffset;
	u8 pgOffset;
	u8 satOffset;
	u8 sprOffset;
	u8 bdColor;
	/// X scroll value
	u8 xScroll;
	/// Y scroll value
	u8 yScroll;
	u8 counter;
	u8 mode3;
	u8 mode4;
	u8 hScrollAdr;
	u8 reg0E;
	u8 reg0F;
	u8 mdRegs[0x10];

	u8 paletteRAM[0x80];
	u8 hCountLatch;
	u8 hCountOffset;
	u8 hCountBP;
	u8 vCountBP;
	u32 regWriteLine;
	u32 scanlineBP;
	u8 type;
	u8 tvType;
	u8 ggMode;
	u8 mode2Bak1;
	u8 mode2Bak2;
	u8 yScrollBak1;
	u8 pgOffsetBak1;
	u8 realMode;
	u8 calcMode;
	u8 heightMode;
	u8 lineState;
	u8 primedVBl;
	u8 debouncePin;
	u8 ntMask;
	u8 sprScan;
	u8 padding1[1];

	u32 scrollMask;
	u32 sprStop;
	u32 lineIRQ;
	u32 nextLineChange;
	u32 padding2[2];

//vdpStateTable:
	u32 zeroLine[2];
	u32 scrStartLine[2];
	u32 midFrameLine[2];
	u32 endFrameLine[2];
	u32 vblLine[2];
	u32 vblEndLine[2];
	u32 secondLastScanline[2];
	u32 lastScanline[2];
	u32 totalScanlines[2];
	u32 padding3[1];

	u32 bgrMapOfs0;
	u32 bgrMapOfs1;
	u32 bgrTileOfs;
	u32 sprTileOfs;
} SegaVDP;


void SegaVDPReset(int chiptype, SegaVDP *vdp);

/**
 * Saves the state of the cpu to the destination.
 * @param  *destination: Where to save the state.
 * @param  *vdp: The SegaVDP to save.
 * @return The size of the state.
 */
int VDPSaveState(void *destination, const SegaVDP *vdp);

/**
 * Loads the state of the cpu from the source.
 * @param  *vdp: The SegaVDP to load a state into.
 * @param  *source: Where to load the state from.
 * @return The size of the state.
 */
int VDPLoadState(SegaVDP *vdp, const void *source);

/**
 * Gets the state size of an SegaVDP state.
 * @return The size of the state.
 */
int VDPGetStateSize(void);

void SegaVDPMixer(SegaVDP *vdp);
void SegaVDPWrite(SegaVDP *vdp, u8 value);

#endif
