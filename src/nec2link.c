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
    gnd.ksymp = 1;
    gnd.nradl = 0;
    gnd.iperf = 0;
    gnd.zrati = CPLX_10;
    gnd.ifar = -1;
    /* Reset the matrix-size flag so nec2_geometry_end recomputes netcx.neq for
       the current geometry. Without this, a stale neq from a previous (larger)
       geometry drives the matrix fill past the freshly allocated arrays and
       segfaults. Matches upstream nec2c (main.c sets matpar.imat = 0 per run). */
    matpar.imat = 0;
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
    /* Wavelength in meters, matching upstream nec2c (main.c: data.wlam = CVEL/fmhz).
       The geometry scale factor below is fr = 1/wlam = mhz/CVEL. */
    data.wlam = CVEL / mhz;
    
    if (data.n != 0) {
        double fr = mhz / CVEL;
        for (int i = 0; i < data.n; i++) {
            data.x[i]  *= fr;
            data.y[i]  *= fr;
            data.z[i]  *= fr;
            data.si[i] *= fr;
            data.bi[i] *= fr;
        }
    }
    
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

DLLEXPORT int nec2_far_field(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    if (Argc < 2) return LIBRARY_FUNCTION_ERROR;
    
    MTensor t_theta = MArgument_getMTensor(Args[0]);
    MTensor t_phi = MArgument_getMTensor(Args[1]);
    
    mint theta_len = libData->MTensor_getFlattenedLength(t_theta);
    mint phi_len = libData->MTensor_getFlattenedLength(t_phi);
    
    double *theta_data = libData->MTensor_getRealData(t_theta);
    double *phi_data = libData->MTensor_getRealData(t_phi);
    
    mint dims[2];
    dims[0] = theta_len * phi_len;
    dims[1] = 7;
    
    MTensor out_tensor;
    int err = libData->MTensor_new(MType_Real, 2, dims, &out_tensor);
    if (err) return err;
    
    double *out_data = libData->MTensor_getRealData(out_tensor);
    
    double gcon = 0.0;
    if (netcx.pin > 1e-20) {
        gcon = data.wlam * data.wlam * 2.0 * PI / (376.73 * netcx.pin);
    }
    
    mint idx = 0;
    for (mint i = 0; i < theta_len; i++) {
        double theta = theta_data[i];
        for (mint j = 0; j < phi_len; j++) {
            double phi = phi_data[j];
            
            complex double eth = 0.0;
            complex double eph = 0.0;
            
            int val = setjmp(nec2c_env);
            if (val == 0) {
                ffld(theta, phi, &eth, &eph);
            } else {
                eth = 0.0;
                eph = 0.0;
            }
            
            double eth_mag2 = creal(eth * conj(eth));
            double eph_mag2 = creal(eph * conj(eph));
            double gain = gcon * (eth_mag2 + eph_mag2);
            
            out_data[idx * 7] = theta;
            out_data[idx * 7 + 1] = phi;
            out_data[idx * 7 + 2] = creal(eth);
            out_data[idx * 7 + 3] = cimag(eth);
            out_data[idx * 7 + 4] = creal(eph);
            out_data[idx * 7 + 5] = cimag(eph);
            out_data[idx * 7 + 6] = gain;
            idx++;
        }
    }
    
    MArgument_setMTensor(Res, out_tensor);
    return LIBRARY_NO_ERROR;
}

DLLEXPORT int nec2_get_input_parameters(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    mint dims[2];
    dims[0] = vsorc.nsant;
    dims[1] = 9;
    
    MTensor out_tensor;
    int err = libData->MTensor_new(MType_Real, 2, dims, &out_tensor);
    if (err) return err;
    
    double *out_data = libData->MTensor_getRealData(out_tensor);
    
    for (int i = 0; i < vsorc.nsant; i++) {
        int seg_idx = vsorc.isant[i] - 1;
        double tag = 0.0;
        if (seg_idx >= 0 && seg_idx < data.n) {
            tag = (double)data.itag[seg_idx];
        }
        
        complex double v = vsorc.vsant[i];
        complex double c = 0.0;
        if (seg_idx >= 0 && seg_idx < data.n) {
            c = crnt.cur[seg_idx];
        }
        
        complex double z = 0.0;
        if (cabs(c) > 1e-20) {
            z = v / c;
        }
        
        double pwr = 0.5 * creal(v * conj(c));
        
        out_data[i * 9] = tag;
        out_data[i * 9 + 1] = (double)(seg_idx + 1);
        out_data[i * 9 + 2] = creal(v);
        out_data[i * 9 + 3] = cimag(v);
        out_data[i * 9 + 4] = creal(c);
        out_data[i * 9 + 5] = cimag(c);
        out_data[i * 9 + 6] = creal(z);
        out_data[i * 9 + 7] = cimag(z);
        out_data[i * 9 + 8] = pwr;
    }
    
    MArgument_setMTensor(Res, out_tensor);
    return LIBRARY_NO_ERROR;
}

DLLEXPORT int nec2_set_ground(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    if (Argc < 6) return LIBRARY_FUNCTION_ERROR;
    
    mint iperf = MArgument_getInteger(Args[0]);
    mint nradl = MArgument_getInteger(Args[1]);
    double epsr = MArgument_getReal(Args[2]);
    double sig = MArgument_getReal(Args[3]);
    double scrwlt = MArgument_getReal(Args[4]);
    double scrwrt = MArgument_getReal(Args[5]);
    
    int val = setjmp(nec2c_env);
    if (val == 0) {
        if (iperf == -1) {
            gnd.ksymp = 1;
            gnd.nradl = 0;
            gnd.iperf = 0;
            gnd.zrati = CPLX_10;
            gnd.frati = CPLX_10;
        } else {
            gnd.iperf = (int)iperf;
            gnd.nradl = (int)nradl;
            gnd.ksymp = 2;
            save.epsr = epsr;
            save.sig = sig;
            
            if (gnd.iperf != 1) {
                complex double epsc = cmplx(save.epsr, -save.sig * data.wlam * 59.96);
                gnd.zrati = 1.0 / csqrt(epsc);
                gnd.frati = (epsc - 1.0) / (epsc + 1.0);
                gwav.u = gnd.zrati;
                gwav.u2 = gwav.u * gwav.u;
                
                if (gnd.nradl != 0) {
                    save.scrwlt = scrwlt;
                    save.scrwrt = scrwrt;
                    gnd.scrwl = save.scrwlt / data.wlam;
                    gnd.scrwr = save.scrwrt / data.wlam;
                    gnd.t1 = CPLX_01 * 2367.067 / (double)gnd.nradl;
                    gnd.t2 = gnd.scrwr * (double)gnd.nradl;
                }
                
                if (gnd.iperf == 2) {
                    /* Allocate and initialize somnec grid buffers if not done already */
                    if (ggrid.ar1 == NULL) {
                        mem_alloc((void *)&ggrid.ar1, sizeof(complex double) * 11 * 10 * 4);
                        mem_alloc((void *)&ggrid.ar2, sizeof(complex double) * 17 * 5 * 4);
                        mem_alloc((void *)&ggrid.ar3, sizeof(complex double) * 9 * 8 * 4);
                        
                        ggrid.nxa[0] = 11; ggrid.nxa[1] = 17; ggrid.nxa[2] = 9;
                        ggrid.nya[0] = 10; ggrid.nya[1] = 5;  ggrid.nya[2] = 8;
                        
                        ggrid.dxa[0] = .02; ggrid.dxa[1] = .05; ggrid.dxa[2] = .1;
                        ggrid.dya[0] = .1745329252; ggrid.dya[1] = .0872664626; ggrid.dya[2] = .1745329252;
                        
                        ggrid.xsa[0] = 0.; ggrid.xsa[1] = .2; ggrid.xsa[2] = .2;
                        ggrid.ysa[0] = 0.; ggrid.ysa[1] = 0.; ggrid.ysa[2] = .3490658504;
                    }
                    somnec(save.epsr, save.sig, save.fmhz);
                }
            } else {
                gnd.zrati = CPLX_10;
                gnd.frati = CPLX_10;
            }
        }
        MArgument_setInteger(Res, 0);
    } else {
        MArgument_setInteger(Res, (val == 256) ? 0 : val);
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
