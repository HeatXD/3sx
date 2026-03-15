// Netplay stubs for the WASM build.
// Netplay requires UDP sockets (GekkoNet) which are unavailable in browsers.
// These no-op stubs satisfy linker references in main.c and the game source.
#ifdef __EMSCRIPTEN__

#include "netplay/netplay.h"
#include "netplay/matchmaking.h"

void               Netplay_SetParams(int player, const char* ip) { (void)player; (void)ip; }
void               Netplay_BeginDirectP2P(void) {}
void               Netplay_TickDirectP2P(void) {}
void               Netplay_SetMatchmakingParams(const char* server_ip, int server_port) { (void)server_ip; (void)server_port; }
void               Netplay_BeginMatchmaking(void) {}
void               Netplay_TickMatchmaking(void) {}
bool               Netplay_IsMatchmakingPending(void) { return false; }
void               Netplay_CancelMatchmaking(void) {}
void               Netplay_Run(void) {}
NetplaySessionState Netplay_GetSessionState(void) { return NETPLAY_SESSION_IDLE; }
void               Netplay_HandleMenuExit(void) {}
void               Netplay_GetNetworkStats(NetworkStats* stats) { (void)stats; }

MatchmakingState    Matchmaking_GetState(void) { return MATCHMAKING_IDLE; }

// Netplay UI renderers (netplay_screen.c / netstats_renderer.c excluded from WASM build)
void NetplayScreen_Render(void) {}
void NetstatsRenderer_Render(void) {}

#endif // __EMSCRIPTEN__
