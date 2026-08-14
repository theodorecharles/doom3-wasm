/*
===========================================================================

Downstream Emscripten GLimp bridge for a worker-owned OffscreenCanvas.

===========================================================================
*/

#include "renderer/tr_local.h"

#include <emscripten.h>
#include <emscripten/html5.h>
#include <emscripten/html5_webgl.h>

static EMSCRIPTEN_WEBGL_CONTEXT_HANDLE webContext = 0;
static glimpParms_t currentParms = {};
static int currentSwapInterval = 1;

// The browser shell transfers its canvas to this dedicated engine worker.  The
// selector-based HTML5 helpers fall back to document.querySelector() in a
// non-pthread worker, where document intentionally does not exist.  Operate on
// the transferred OffscreenCanvas directly instead.
EM_JS( EMSCRIPTEN_WEBGL_CONTEXT_HANDLE, D3WASM_CreateWorkerWebGLContext,
	( int alpha, int antialias ), {
	const canvas = Module['canvas'];
	if ( !canvas || typeof canvas.getContext !== 'function' ) {
		return 0;
	}
	return GL.createContext( canvas, {
		alpha: !!alpha,
		depth: true,
		stencil: true,
		antialias: !!antialias,
		premultipliedAlpha: true,
		preserveDrawingBuffer: false,
		powerPreference: 'high-performance',
		failIfMajorPerformanceCaveat: false,
		majorVersion: 2,
		minorVersion: 0,
		enableExtensionsByDefault: true,
		explicitSwapControl: true,
		proxyContextToMainThread: 0,
		renderViaOffscreenBackBuffer: false
	});
} );

EM_JS( int, D3WASM_ResizeWorkerCanvas, ( int width, int height ), {
	const canvas = Module['canvas'];
	if ( !canvas ) {
		return 0;
	}
	canvas.width = width;
	canvas.height = height;
	return 1;
} );

bool GLimp_Init( glimpParms_t parms ) {
	common->Printf( "[doom3-wasm] creating worker WebGL 2 context\n" );

	webContext = D3WASM_CreateWorkerWebGLContext( 1, parms.multiSamples > 0 ? 1 : 0 );
	if ( webContext <= 0 ) {
		common->Warning( "emscripten_webgl_create_context failed: %ld\n", static_cast<long>( webContext ) );
		return false;
	}
	if ( emscripten_webgl_make_context_current( webContext ) != EMSCRIPTEN_RESULT_SUCCESS ) {
		common->Warning( "Could not make worker WebGL context current\n" );
		emscripten_webgl_destroy_context( webContext );
		webContext = 0;
		return false;
	}

	currentParms = parms;
	glConfig.vidWidth = parms.width;
	glConfig.vidHeight = parms.height;
	glConfig.winWidth = parms.width;
	glConfig.winHeight = parms.height;
	glConfig.isFullscreen = false;
	D3WASM_ResizeWorkerCanvas( parms.width, parms.height );
	common->Printf( "[doom3-wasm] worker WebGL 2 context is current at %d x %d\n", parms.width, parms.height );
	return true;
}

bool GLimp_SetScreenParms( glimpParms_t parms ) {
	currentParms = parms;
	glConfig.vidWidth = parms.width;
	glConfig.vidHeight = parms.height;
	glConfig.winWidth = parms.width;
	glConfig.winHeight = parms.height;
	glConfig.isFullscreen = false;
	return D3WASM_ResizeWorkerCanvas( parms.width, parms.height ) != 0;
}

float GLimp_GetDisplayRefresh() {
	return 60.0f;
}

glimpParms_t GLimp_GetCurState() {
	return currentParms;
}

void GLimp_Shutdown() {
	if ( webContext ) {
		emscripten_webgl_destroy_context( webContext );
		webContext = 0;
	}
}

void GLimp_SwapBuffers() {
	emscripten_webgl_commit_frame();
}

void GLimp_SetGamma( unsigned short[256], unsigned short[256], unsigned short[256] ) {
}

void GLimp_ResetGamma() {
}

void GLimp_ActivateContext() {
	if ( webContext ) {
		emscripten_webgl_make_context_current( webContext );
	}
}

void GLimp_DeactivateContext() {
	emscripten_webgl_make_context_current( 0 );
}

GLExtension_t GLimp_ExtensionPointer( const char *name ) {
	return reinterpret_cast<GLExtension_t>( emscripten_webgl_get_proc_address( name ) );
}

void GLimp_GrabInput( int ) {
}

bool GLimp_SetSwapInterval( int swapInterval ) {
	currentSwapInterval = swapInterval;
	return true;
}

int GLimp_GetSwapInterval() {
	return currentSwapInterval;
}

bool GLimp_SetWindowResizable( bool ) {
	return true;
}

void GLimp_UpdateWindowSize() {
	glConfig.vidWidth = currentParms.width;
	glConfig.vidHeight = currentParms.height;
	glConfig.winWidth = currentParms.width;
	glConfig.winHeight = currentParms.height;
}

extern "C" EMSCRIPTEN_KEEPALIVE int D3WASM_BrowserResize( int width, int height ) {
	if ( width < 320 || height < 200 ) {
		return 0;
	}
	glimpParms_t parms = currentParms;
	parms.width = width;
	parms.height = height;
	return GLimp_SetScreenParms( parms ) ? 1 : 0;
}
