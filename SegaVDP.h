//
//  SegaVDP.h
//  Sega VDP chip emulator for GBA/NDS.
//
//  Created by Fredrik Ahlström on 2012-03-10.
//  Copyright © 2012-2023 Fredrik Ahlström. All rights reserved.
//

#ifndef SegaVDP_HEADER
#define SegaVDP_HEADER

#define VDPSTATESIZE	(0xE0)

typedef struct {
	u8 *dirtyTiles[0x200];
	u8 spriteTileBuffer[0x20];
	u8 spritePosBuffer[0x20];
	u8 vdpJumpTable[0x80];
	u8 vdpCtrlTable[0x10];
	/// Horizontal scrollbuffer.
	u8 scrollBuff[320];
	/// Tilemap buffer.
	u8 TMapBuff[320];
	u8 *VRAMPtr;
	u8 *VRAMCopyPtr;
	u8 *vdpModesPtr;
	u8 *irqRoutine;
	u8 *debounceRoutine;
	u8 *vdpScanlineHook;
	u8 *vdpTmpOAMBuffer;
	u8 *vdpDMAOAMBuffer;
	u8 *vdpDirtyTilesPtr;
	u8 vdpPadding0[0x0C];

//vdpState:
	u32 vdpAdr;
	int vdpScanline;
	/// vdpbuff + toggle need to be together in this way.
	u8 vdpBuff[2];
	u8 vdpToggle[2];
	u8 vdpBuffMD;
	u8 vdpCtrl;
	/// VBlank + spr stat
	u8 vdpStat;
	/// Line interrupt pending
	u8 vdpPending;

	u8 vdpMode1;
	u8 vdpMode2;
	u8 vdpNameTable;
	u8 vdpCTOffset;
	u8 vdpPGOffset;
	u8 vdpSATOffset;
	u8 vdpSPROffset;
	u8 vdpBDColor;
	/// X scroll value
	u8 vdpXScroll;
	/// Y scroll value
	u8 vdpYScroll;
	u8 vdpCounter;
	u8 vdpMode3;
	u8 vdpMode4;
	u8 vdpHScrollAdr;
	u8 vdpReg0E;
	u8 vdpReg0F;
	u8 vdpMDRegs[0x10];

	u8 vdpPaletteRAM[0x80];
	u8 vdpHCountLatch;
	u8 vdpHCountOffset;
	u8 vdpHCountBP;
	u8 vdpVCountBP;
	u32 vdpNametableLine;
	u32 vdpScrollXLine;
	u32 vdpScanlineBP;
	u8 vdpType;
	u8 vdpTVType;
	u8 vdpGGMode;
	u8 vdpMode2Bak1;
	u8 vdpMode2Bak2;
	u8 vdpYScrollBak1;
	u8 vdpPGOffsetBak1;
	u8 vdpRealMode;
	u8 vdpCalcMode;
	u8 vdpHeightMode;
	u8 vdpLineState;
	u8 vdpPrimedVBl;
	u8 vdpDebouncePin;
	u8 vdpNTMask;
	u8 vdpPadding1[2];
	u32 vdpScrollMask;
	u32 vdpSprStop;
	u32 vdpLineIRQ;
	u32 vdpNextLineChange;
	u32 vdpPadding2[1];

//vdpStateTable:
	u32 vdpZeroLine[2];
	u32 vdpScrStartLine[2];
	u32 vdpMidFrameLine[2];
	u32 vdpEndFrameLine[2];
	u32 vdpVBlLine[2];
	u32 vdpVBlEndLine[2];
	u32 vdp2ndLastScanline[2];
	u32 vdpLastScanline[2];
	u32 vdpTotalScanlines[2];
	u32 vdpPadding3[1];

	u32 vdpBgrMapOfs0;
	u32 vdpBgrMapOfs1;
	u32 vdpBgrTileOfs;
	u32 vdpSprTileOfs;
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
