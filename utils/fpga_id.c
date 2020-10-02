/*

Copyright 2020, The Regents of the University of California.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

   1. Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.

   2. Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE REGENTS OF THE UNIVERSITY OF CALIFORNIA ''AS
IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE REGENTS OF THE UNIVERSITY OF CALIFORNIA OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those
of the authors and should not be interpreted as representing official policies,
either expressed or implied, of The Regents of the University of California.

*/

#include "fpga_id.h"

struct fpga_id {
    int id;
    char part[16];
};

const struct fpga_id fpga_id_list[] = 
{
    // Artix 7
    {FPGA_ID_XC7A15T,     "XC7A15T"},
    {FPGA_ID_XC7A35T,     "XC7A35T"},
    {FPGA_ID_XC7A50T,     "XC7A50T"},
    {FPGA_ID_XC7A75T,     "XC7A75T"},
    {FPGA_ID_XC7A100T,    "XC7A100T"},
    {FPGA_ID_XC7A200T,    "XC7A200T"},
    // Kintex 7
    {FPGA_ID_XC7K70T,     "XC7K70T"},
    {FPGA_ID_XC7K160T,    "XC7K160T"},
    {FPGA_ID_XC7K325T,    "XC7K325T"},
    {FPGA_ID_XC7K355T,    "XC7K355T"},
    {FPGA_ID_XC7K410T,    "XC7K410T"},
    {FPGA_ID_XC7K420T,    "XC7K420T"},
    {FPGA_ID_XC7K480T,    "XC7K480T"},
    // Virtex 7
    {FPGA_ID_XC7V585T,    "XC7V585T"},
    {FPGA_ID_XC7V2000T,   "XC7V2000T"},
    {FPGA_ID_XC7VX330T,   "XC7VX330T"},
    {FPGA_ID_XC7VX415T,   "XC7VX415T"},
    {FPGA_ID_XC7VX485T,   "XC7VX485T"},
    {FPGA_ID_XC7VX550T,   "XC7VX550T"},
    {FPGA_ID_XC7VX690T,   "XC7VX690T"},
    {FPGA_ID_XC7VX980T,   "XC7VX980T"},
    {FPGA_ID_XC7VX1140T,  "XC7VX1140T"},
    {FPGA_ID_XC7VH580T,   "XC7VH580T"},
    {FPGA_ID_XC7VH870T,   "XC7VH870T"},
    // Kintex Ultrascale
    {FPGA_ID_XCKU025,     "XCKU025"},
    {FPGA_ID_XCKU035,     "XCKU035"},
    {FPGA_ID_XCKU040,     "XCKU040"},
    {FPGA_ID_XCKU060,     "XCKU060"},
    {FPGA_ID_XCKU085,     "XCKU085"},
    {FPGA_ID_XCKU095,     "XCKU095"},
    {FPGA_ID_XCKU115,     "XCKU115"},
    // Virtex Ultrascale
    {FPGA_ID_XCVU065,     "XCVU065"},
    {FPGA_ID_XCVU080,     "XCVU080"},
    {FPGA_ID_XCVU095,     "XCVU095"},
    {FPGA_ID_XCVU125,     "XCVU125"},
    {FPGA_ID_XCVU160,     "XCVU160"},
    {FPGA_ID_XCVU190,     "XCVU190"},
    {FPGA_ID_XCVU440,     "XCVU440"},
    // Kintex Ultrascale+
    {FPGA_ID_XCKU3P,      "XCKU3P"},
    {FPGA_ID_XCKU5P,      "XCKU5P"},
    {FPGA_ID_XCKU9P,      "XCKU9P"},
    {FPGA_ID_XCKU11P,     "XCKU11P"},
    {FPGA_ID_XCKU13P,     "XCKU13P"},
    {FPGA_ID_XCKU15P,     "XCKU15P"},
    // Virtex Ultrascale+
    {FPGA_ID_XCVU3P,      "XCVU3P"},
    {FPGA_ID_XCVU5P,      "XCVU5P"},
    {FPGA_ID_XCVU7P,      "XCVU7P"},
    {FPGA_ID_XCVU9P,      "XCVU9P"},
    {FPGA_ID_XCVU11P,     "XCVU11P"},
    {FPGA_ID_XCVU13P,     "XCVU13P"},
    // Zynq Ultrascale+
    {FPGA_ID_XCZU2,       "XCZU2"},
    {FPGA_ID_XCZU3,       "XCZU3"},
    {FPGA_ID_XCZU4,       "XCZU4"},
    {FPGA_ID_XCZU5,       "XCZU5"},
    {FPGA_ID_XCZU6,       "XCZU6"},
    {FPGA_ID_XCZU7,       "XCZU7"},
    {FPGA_ID_XCZU9,       "XCZU9"},
    {FPGA_ID_XCZU11,      "XCZU11"},
    {FPGA_ID_XCZU15,      "XCZU15"},
    {FPGA_ID_XCZU17,      "XCZU17"},
    {FPGA_ID_XCZU19,      "XCZU19"},
    {FPGA_ID_XCZU21,      "XCZU21"},
    {FPGA_ID_XCZU25,      "XCZU25"},
    {FPGA_ID_XCZU27,      "XCZU27"},
    {FPGA_ID_XCZU28,      "XCZU28"},
    {FPGA_ID_XCZU29,      "XCZU29"},
    // Alveo
    {FPGA_ID_XCU50,       "XCU50"},
    {FPGA_ID_XCU200,      "XCU200"},
    {FPGA_ID_XCU250,      "XCU250"},
    {FPGA_ID_XCU280,      "XCU280"},
    {0, ""}
};

const char *get_fpga_part(int id)
{
    const struct fpga_id *ptr = fpga_id_list;

    id = id & 0x0fffffff; // mask off version

    while (ptr->id && ptr->id != id)
    {
        ptr++;
    }

    return ptr->part;
}

