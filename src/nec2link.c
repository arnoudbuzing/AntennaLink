#include "WolframLibrary.h"
#include <setjmp.h>
#include <string.h>
#include <stdio.h>
#include <signal.h>

jmp_buf nec2c_env;

void nec2c_exit(int code) {
    longjmp(nec2c_env, code == 0 ? 256 : code);
}

#define exit nec2c_exit
#define sigaction(a,b,c) 0
#define PACKAGE_STRING "nec2c 1.3"
#define version "1.3"

/* Include the nec2c headers and shared data to access globals directly */
#include "nec2c.h"
#include "shared.h"

#define main old_main
#include "main.c"
#undef main
#undef exit

/* ========================================================================= */
/* Original Option A Interface                                               */
/* ========================================================================= */

DLLEXPORT int run_nec2(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    char *inputFile;
    char *outputFile;
    int argc = 5;
    char *argv[5];
    int result = 0;
    
    inputFile = MArgument_getUTF8String(Args[0]);
    outputFile = MArgument_getUTF8String(Args[1]);
    
    argv[0] = "nec2c";
    argv[1] = "-i";
    argv[2] = inputFile;
    argv[3] = "-o";
    argv[4] = outputFile;
    
    /* Reset getopt state for multiple calls in the same process */
    optind = 1;
#ifdef __APPLE__
    optreset = 1;
#endif

    int val = setjmp(nec2c_env);
    if (val == 0) {
        old_main(argc, argv);
    } else {
        result = (val == 256) ? 0 : val;
    }
    
    libData->UTF8String_disown(inputFile);
    libData->UTF8String_disown(outputFile);
    
    MArgument_setInteger(Res, result);
    return LIBRARY_NO_ERROR;
}

/* ========================================================================= */
/* Memory Interface                                                          */
/* ========================================================================= */

DLLEXPORT int nec2_init(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    Null_Pointers();
    data.n = 0;
    data.np = 0;
    data.m = 0;
    data.mp = 0;
    vsorc.nsant = 0;
    vsorc.nvqd = 0;
    netcx.nonet = 0;
    zload.nload = 0;
    data.ipsym = 0;
    output_fp = stdout;
    plot_fp = stdout;
    return LIBRARY_NO_ERROR;
}

DLLEXPORT int nec2_add_wire(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    mint segs = MArgument_getInteger(Args[0]);
    mint tag = MArgument_getInteger(Args[1]);
    MTensor t1 = MArgument_getMTensor(Args[2]);
    MTensor t2 = MArgument_getMTensor(Args[3]);
    double rad = MArgument_getReal(Args[4]);
    
    double *p1 = libData->MTensor_getRealData(t1);
    double *p2 = libData->MTensor_getRealData(t2);
    
    int val = setjmp(nec2c_env);
    if (val == 0) {
        wire(p1[0], p1[1], p1[2], p2[0], p2[1], p2[2], rad, 1.0, 1.0, (int)segs, (int)tag);
        MArgument_setInteger(Res, 0);
    } else {
        MArgument_setInteger(Res, (val == 256) ? 0 : val);
    }
    return LIBRARY_NO_ERROR;
}

DLLEXPORT int nec2_geometry_end(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    mint ignd = MArgument_getInteger(Args[0]);
    
    int val = setjmp(nec2c_env);
    if (val == 0) {
        conect((int)ignd);
        
        /* Set array sizes explicitly before reallocation! */
        data.npm = data.n + data.m;
        data.np2m = data.n + 2 * data.m;
        data.np3m = data.n + 3 * data.m;
        
        if (data.n != 0) {
            size_t mreq = (size_t)data.n;
            mreq *= sizeof(double);
            mem_realloc((void *)&data.si, mreq);
            mem_realloc((void *)&data.sab, mreq);
            mem_realloc((void *)&data.cab, mreq);
            mem_realloc((void *)&data.salp, mreq);
            mem_realloc((void *)&data.x, mreq);
            mem_realloc((void *)&data.y, mreq);
            mem_realloc((void *)&data.z, mreq);
            
            for(int i = 0; i < data.n; i++) {
                double xw1 = data.x2[i] - data.x1[i];
                double yw1 = data.y2[i] - data.y1[i];
                double zw1 = data.z2[i] - data.z1[i];
                data.x[i] = (data.x1[i] + data.x2[i]) / 2.;
                data.y[i] = (data.y1[i] + data.y2[i]) / 2.;
                data.z[i] = (data.z1[i] + data.z2[i]) / 2.;
                
                double xw2 = xw1*xw1 + yw1*yw1 + zw1*zw1;
                double yw2 = sqrt(xw2);
                yw2 = (xw2 / yw2 + yw2) * 0.5;
                data.si[i] = yw2;
                data.cab[i] = xw1 / yw2;
                data.sab[i] = yw1 / yw2;
                xw2 = zw1 / yw2;
                
                if(xw2 > 1.) xw2 = 1.;
                if(xw2 < -1.) xw2 = -1.;
                
                data.salp[i] = xw2;
            }
        }
        
        size_t mreq = (size_t)data.npm * sizeof(double);
        mem_realloc((void *)&crnt.air, mreq);
        mem_realloc((void *)&crnt.aii, mreq);
        mem_realloc((void *)&crnt.bir, mreq);
        mem_realloc((void *)&crnt.bii, mreq);
        mem_realloc((void *)&crnt.cir, mreq);
        mem_realloc((void *)&crnt.cii, mreq);
        
        mreq = (size_t)data.np2m * sizeof(int);
        mem_realloc((void *)&save.ip, mreq);
        
        mreq = (size_t)data.np3m * sizeof(complex double);
        mem_realloc((void *)&crnt.cur, mreq);
        
        if (matpar.imat == 0) {
            netcx.neq = data.n + 2 * data.m;
            netcx.neq2 = 0;
        }
        netcx.npeq = data.np + 2 * data.mp;
        
        MArgument_setInteger(Res, 0);
    } else {
        MArgument_setInteger(Res, (val == 256) ? 0 : val);
    }
    return LIBRARY_NO_ERROR;
}

DLLEXPORT int nec2_set_freq(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    double mhz = MArgument_getReal(Args[0]);
    save.fmhz = mhz;
    data.wlam = CVEL / mhz;
    return LIBRARY_NO_ERROR;
}

DLLEXPORT int nec2_set_excitation(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    mint tag = MArgument_getInteger(Args[0]);
    mint seg = MArgument_getInteger(Args[1]);
    double v_real = MArgument_getReal(Args[2]);
    double v_imag = MArgument_getReal(Args[3]);
    
    int val = setjmp(nec2c_env);
    if (val == 0) {
        fpat.ixtyp = 0; 
        netcx.ntsol = 0;
        
        vsorc.nsant++;
        size_t mreq = (size_t)vsorc.nsant * sizeof(int);
        mem_realloc((void *)&vsorc.isant, mreq);
        
        mreq = (size_t)vsorc.nsant * sizeof(complex double);
        mem_realloc((void *)&vsorc.vsant, mreq);
        
        int idx = vsorc.nsant - 1;
        vsorc.isant[idx] = isegno((int)tag, (int)seg);
        vsorc.vsant[idx] = cmplx(v_real, v_imag);
        if (cabs(vsorc.vsant[idx]) < 1.e-20) vsorc.vsant[idx] = CPLX_10;
        
        MArgument_setInteger(Res, 0);
    } else {
        MArgument_setInteger(Res, (val == 256) ? 0 : val);
    }
    
    return LIBRARY_NO_ERROR;
}

DLLEXPORT int nec2_execute(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    complex double *cm = NULL;
    
    int val = setjmp(nec2c_env);
    if (val == 0) {
        size_t mreq = (size_t)netcx.neq * netcx.npeq;
        mem_realloc((void *)&cm, mreq * sizeof(complex double));
    
        double rkh = 1.;
        int iexk = 0;
        
        gnd.ksymp = 1;
        gnd.nradl = 0;
        gnd.iperf = 0;
        gnd.zrati = CPLX_10;
        
        matpar.icase = 1;
        matpar.npblk = 1;
        matpar.nlast = netcx.npeq;
        
        cmset(netcx.neq, cm, rkh, iexk);
        factrs(netcx.npeq, netcx.neq, cm, save.ip);
        
        netcx.ntsol = 0;
        
        etmns(0., 0., 0., 0., 0., 0., fpat.ixtyp, crnt.cur);
        
        netwk(cm, save.ip, crnt.cur);
        netcx.ntsol = 1;
        
        mint dims[2];
        dims[0] = data.n;
        dims[1] = 5; 
        MTensor tensor;
        libData->MTensor_new(MType_Real, 2, dims, &tensor);
        double *tensor_data = libData->MTensor_getRealData(tensor);
        
        for (int i = 0; i < data.n; i++) {
            tensor_data[i*5] = creal(crnt.cur[i]);
            tensor_data[i*5 + 1] = cimag(crnt.cur[i]);
            tensor_data[i*5 + 2] = data.x[i];
            tensor_data[i*5 + 3] = data.y[i];
            tensor_data[i*5 + 4] = data.z[i];
        }
        
        MArgument_setMTensor(Res, tensor);
    } else {
        MTensor tensor;
        mint dims[1] = {0};
        libData->MTensor_new(MType_Real, 1, dims, &tensor);
        MArgument_setMTensor(Res, tensor);
    }
    
    if (cm != NULL) {
        free_ptr((void *)&cm);
    }
    
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
