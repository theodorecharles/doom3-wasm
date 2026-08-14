/*
===========================================================================

Downstream Emscripten GLimp bridge for a worker-owned OffscreenCanvas.

===========================================================================
*/

#include "renderer/tr_local.h"

#include <emscripten/html5.h>
#include <emscripten/html5_webgl.h>

static EMSCRIPTEN_WEBGL_CONTEXT_HANDLE webContext = 0;
static glimpParms_t currentParms = {};
static int currentSwapInterval = 1;

bool GLimp_Init( glimpParms_t parms ) {
	common->Printf( "[doom3-wasm] creating worker WebGL 2 context\n" );

	EmscriptenWebGLContextAttributes attributes;
	emscripten_webgl_init_context_attributes( &attributes );
	attributes.alpha = EM_TRUE;
	attributes.depth = EM_TRUE;
	attributes.stencil = EM_TRUE;
	attributes.antialias = parms.multiSamples > 0 ? EM_TRUE : EM_FALSE;
	attributes.majorVersion = 2;
	attributes.minorVersion = 0;
	attributes.enableExtensionsByDefault = EM_TRUE;
	attributes.explicitSwapControl = EM_TRUE;

	webContext = emscripten_webgl_create_context( "#canvas", &attributes );
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
	emscripten_set_canvas_element_size( "#canvas", parms.width, parms.height );
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
	return emscripten_set_canvas_element_size( "#canvas", parms.width, parms.height ) == EMSCRIPTEN_RESULT_SUCCESS;
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
	int width = currentParms.width;
	int height = currentParms.height;
	if ( emscripten_get_canvas_element_size( "#canvas", &width, &height ) == EMSCRIPTEN_RESULT_SUCCESS ) {
		glConfig.vidWidth = width;
		glConfig.vidHeight = height;
		glConfig.winWidth = width;
		glConfig.winHeight = height;
	}
}
