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

#ifndef FPGA_ID_H
#define FPGA_ID_H

// Artix 7
#define FPGA_ID_XC7A15T     0x362D093
#define FPGA_ID_XC7A35T     0x362D093
#define FPGA_ID_XC7A50T     0x362C093
#define FPGA_ID_XC7A75T     0x3632093
#define FPGA_ID_XC7A100T    0x3631093
#define FPGA_ID_XC7A200T    0x3636093
// Kintex 7
#define FPGA_ID_XC7K70T     0x3647093
#define FPGA_ID_XC7K160T    0x364C093
#define FPGA_ID_XC7K325T    0x3651093
#define FPGA_ID_XC7K355T    0x3747093
#define FPGA_ID_XC7K410T    0x3656093
#define FPGA_ID_XC7K420T    0x3752093
#define FPGA_ID_XC7K480T    0x3751093
// Virtex 7
#define FPGA_ID_XC7V585T    0x3671093
#define FPGA_ID_XC7V2000T   0x36B3093
#define FPGA_ID_XC7VX330T   0x3667093
#define FPGA_ID_XC7VX415T   0x3682093
#define FPGA_ID_XC7VX485T   0x3687093
#define FPGA_ID_XC7VX550T   0x3692093
#define FPGA_ID_XC7VX690T   0x3691093
#define FPGA_ID_XC7VX980T   0x3696093
#define FPGA_ID_XC7VX1140T  0x36D5093
#define FPGA_ID_XC7VH580T   0x36D9093
#define FPGA_ID_XC7VH870T   0x36DB093
// Kintex Ultrascale
#define FPGA_ID_XCKU025     0x3824093
#define FPGA_ID_XCKU035     0x3823093
#define FPGA_ID_XCKU040     0x3822093
#define FPGA_ID_XCKU060     0x3919093
#define FPGA_ID_XCKU085     0x380F093
#define FPGA_ID_XCKU095     0x3844093
#define FPGA_ID_XCKU115     0x390D093
// Virtex Ultrascale
#define FPGA_ID_XCVU065     0x3939093
#define FPGA_ID_XCVU080     0x3843093
#define FPGA_ID_XCVU095     0x3842093
#define FPGA_ID_XCVU125     0x392D093
#define FPGA_ID_XCVU160     0x3933093
#define FPGA_ID_XCVU190     0x3931093
#define FPGA_ID_XCVU440     0x396D093
// Kintex Ultrascale+
#define FPGA_ID_XCKU3P      0x4A63093
#define FPGA_ID_XCKU5P      0x4A62093
#define FPGA_ID_XCKU9P      0x484A093
#define FPGA_ID_XCKU11P     0x4A4E093
#define FPGA_ID_XCKU13P     0x4A52093
#define FPGA_ID_XCKU15P     0x4A56093
// Virtex Ultrascale+
#define FPGA_ID_XCVU3P      0x4B39093
#define FPGA_ID_XCVU5P      0x4B2B093
#define FPGA_ID_XCVU7P      0x4B29093
#define FPGA_ID_XCVU9P      0x4B31093
#define FPGA_ID_XCVU11P     0x4B49093
#define FPGA_ID_XCVU13P     0x4B51093
// Zynq Ultrascale+
#define FPGA_ID_XCZU2       0x4711093
#define FPGA_ID_XCZU3       0x4710093
#define FPGA_ID_XCZU4       0x4721093
#define FPGA_ID_XCZU5       0x4720093
#define FPGA_ID_XCZU6       0x4739093
#define FPGA_ID_XCZU7       0x4730093
#define FPGA_ID_XCZU9       0x4738093
#define FPGA_ID_XCZU11      0x4740093
#define FPGA_ID_XCZU15      0x4750093
#define FPGA_ID_XCZU17      0x4759093
#define FPGA_ID_XCZU19      0x4758093
#define FPGA_ID_XCZU21      0x47E1093
#define FPGA_ID_XCZU25      0x47E5093
#define FPGA_ID_XCZU27      0x47E4093
#define FPGA_ID_XCZU28      0x47E0093
#define FPGA_ID_XCZU29      0x47E2093
// Alveo
#define FPGA_ID_XCU50       0x4B77093
#define FPGA_ID_XCU200      0x4B37093
#define FPGA_ID_XCU250      0x4B57093
#define FPGA_ID_XCU280      0x4B7D093

const char *get_fpga_part(int id);

#endif /* FPGA_ID_H */
