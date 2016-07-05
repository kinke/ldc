// Compiler implementation of the D programming language
// Copyright (c) 1999-2016 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.root.ctfloat;

static import core.math, core.stdc.math;
import core.stdc.errno;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

version(IN_LLVM) {} else version(CRuntime_Microsoft) version = CRuntime_Microsoft_X87;

// Type used by the front-end for compile-time reals
version(IN_LLVM_MSVC)
    alias real_t = double;
else
alias real_t = real;

private
{
    version(CRuntime_DigitalMars) __gshared extern (C) extern const(char)* __locale_decpoint;

    version(CRuntime_Microsoft_X87) extern (C++)
    {
        struct longdouble { real_t r; }
        size_t ld_sprint(char* str, int fmt, longdouble x);
        longdouble strtold_dm(const(char)* p, char** endp);
    }
}

// Compile-time floating-point helper
extern (C++) struct CTFloat
{
    version(DigitalMars)
    {
        static __gshared bool yl2x_supported = true;
        static __gshared bool yl2xp1_supported = true;
    }
    else
    {
        static __gshared bool yl2x_supported = false;
        static __gshared bool yl2xp1_supported = false;
    }

    static void yl2x(const real_t* x, const real_t* y, real_t* res)
    {
        version(DigitalMars)
            *res = core.math.yl2x(*x, *y);
        else
            assert(0);
    }

    static void yl2xp1(const real_t* x, const real_t* y, real_t* res)
    {
        version(DigitalMars)
            *res = core.math.yl2xp1(*x, *y);
        else
            assert(0);
    }

    static real_t sin(real_t x) { return core.math.sin(x); }
    static real_t cos(real_t x) { return core.math.cos(x); }
    static real_t tan(real_t x) { return core.stdc.math.tanl(x); }
    static real_t sqrt(real_t x) { return core.math.sqrt(x); }
    static real_t fabs(real_t x) { return core.math.fabs(x); }

    static bool isIdentical(real_t a, real_t b)
    {
        // LDC specific
        static if (real_t.sizeof == double.sizeof)
            enum unpaddedSize = 8;
        else
            enum unpaddedSize = 10;
        return memcmp(&a, &b, unpaddedSize) == 0;
    }

    static bool isNaN(real_t r)
    {
        return !(r == r);
    }

    static bool isSNaN(real_t r)
    {
        // LDC specific
        static if (real_t.sizeof == double.sizeof)
            return isNaN(r) && !(((cast(ubyte*)&r)[6]) & 8);
        else
        return isNaN(r) && !(((cast(ubyte*)&r)[7]) & 0x40);
    }

    static bool isInfinity(real_t r)
    {
        return r is real_t.infinity || r is -real_t.infinity;
    }

    static real_t parse(const(char)* literal, bool* isOutOfRange = null)
    {
        errno = 0;
        version(CRuntime_DigitalMars)
        {
            auto save = __locale_decpoint;
            __locale_decpoint = ".";
        }
        version(CRuntime_Microsoft_X87)
            auto r = strtold_dm(literal, null).r;
        else
            auto r = strtold(literal, null);
        version(CRuntime_DigitalMars) __locale_decpoint = save;
        if (isOutOfRange)
            *isOutOfRange = (errno == ERANGE);
        return r;
    }

    static int sprint(char* str, char fmt, real_t x)
    {
        version(CRuntime_Microsoft_X87)
        {
            return cast(int)ld_sprint(str, fmt, longdouble(x));
        }
        else
        {
            if (real_t(cast(ulong)x) == x)
            {
                // ((1.5 -> 1 -> 1.0) == 1.5) is false
                // ((1.0 -> 1 -> 1.0) == 1.0) is true
                // see http://en.cppreference.com/w/cpp/io/c/fprintf
                char[5] sfmt = "%#Lg\0";
                sfmt[3] = fmt;
                return sprintf(str, sfmt.ptr, x);
            }
            else
            {
                char[4] sfmt = "%Lg\0";
                sfmt[2] = fmt;
                return sprintf(str, sfmt.ptr, x);
            }
        }
    }
}
