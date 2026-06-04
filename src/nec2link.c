#include "WolframLibrary.h"
#include <setjmp.h>
#include <string.h>
#include <stdio.h>
#include <signal.h>

jmp_buf nec2c_env;

/* Intercept exit() calls from nec2c to prevent crashing the Wolfram Kernel */
void nec2c_exit(int code) {
    longjmp(nec2c_env, code == 0 ? 256 : code);
}

#define exit nec2c_exit
#define sigaction(a,b,c) 0
#define PACKAGE_STRING "nec2c 1.3"
#define version "1.3"

/* Include main.c directly to apply the macros without CCompilerDriver escaping issues */
#include "main.c"

#undef exit

DLLEXPORT int run_nec2(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    char *inFile = MArgument_getUTF8String(Args[0]);
    char *outFile = MArgument_getUTF8String(Args[1]);
    
    char *argv[] = {"nec2c", "-i", inFile, "-o", outFile};
    int argc = 5;
    
    int val = setjmp(nec2c_env);
    if (val == 0) {
        /* Run the main function of nec2c (now safely included) */
        main(argc, argv);
        MArgument_setInteger(Res, 0);
    } else {
        /* Returned via longjmp (exit called) */
        int err = (val == 256) ? 0 : val;
        MArgument_setInteger(Res, err);
    }
    
    libData->UTF8String_disown(inFile);
    libData->UTF8String_disown(outFile);
    return LIBRARY_NO_ERROR;
}

DLLEXPORT mint WolframLibrary_getVersion(void) {
    return WolframLibraryVersion;
}

DLLEXPORT int WolframLibrary_initialize(WolframLibraryData libData) {
    return LIBRARY_NO_ERROR;
}

DLLEXPORT void WolframLibrary_uninitialize(WolframLibraryData libData) {
    return;
}
