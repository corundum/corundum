#!/usr/bin/env python3
"""

Copyright (c) 2022 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

"""

import argparse
import asyncio
import configparser
import datetime
import os
import re
import shlex
import subprocess


config = configparser.ConfigParser()


def run_cmd(cmd, cwd=None):
    return subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE).stdout.decode('utf-8').strip()


async def run_cmd_async(cmd, *args, cwd=None):
    proc = await asyncio.create_subprocess_exec(
        cmd,
        *args,
        cwd=cwd,
        stdout=asyncio.subprocess.PIPE)

    stdout, stderr = await proc.communicate()

    if stdout:
        return stdout.decode()

    return None


async def run_cmd_shell_async(cmd, cwd=None):
    proc = await asyncio.create_subprocess_shell(
        cmd,
        cwd=cwd,
        stdout=asyncio.subprocess.PIPE)

    stdout, stderr = await proc.communicate()

    if stdout:
        return stdout.decode()

    return None


class Build:
    def __init__(self, design, build_dir, prefix, output):
        self.design = design
        self.prefix = prefix
        self.output = output

        self.settings_file = ""
        self.build_dir = build_dir
        self.build_cmd = "sleep 5"

        self.outname = '-'.join(self.design)
        if prefix:
            self.outname = prefix + "-" + self.outname

        self.output_file = ""
        self.output_ext = ".bin"

        self.start_time = None
        self.elapsed_time = None

        self.wns = None
        self.tns = None

        self.phase = "Idle"

    def get_status(self):
        s = f"{'/'.join(self.design)}: {self.phase}"

        if self.wns is not None:
            s += f" (WNS: {self.wns}, TNS: {self.tns})"

        if self.elapsed_time is not None:
            s += " ["+str(self.elapsed_time).split('.')[0]+"]"
        elif self.start_time is not None:
            s += " ["+str(datetime.datetime.now() - self.start_time).split('.')[0]+"]"

        return s

    def synth_done(self):
        if self.synth_sem is not None:
            self.synth_sem.release()
            self.synth_sem = None

    def build_done(self):
        if self.build_sem is not None:
            self.build_sem.release()
            self.build_sem = None

    async def run(self, build_sem, synth_sem):
        self.build_sem = build_sem
        self.synth_sem = synth_sem

        self.phase = "Waiting (build)"
        if self.build_sem is not None:
            await self.build_sem.acquire()

        self.phase = "Waiting (synth)"
        if self.synth_sem is not None:
            await self.synth_sem.acquire()

        self.phase = "Starting"
        self.start_time = datetime.datetime.now()

        build_cmd = self.build_cmd
        if self.settings_file:
            build_cmd = f"source {self.settings_file}; {build_cmd}"

        build_cmd = "bash -c " + shlex.quote(build_cmd)

        proc = await asyncio.create_subprocess_shell(
            build_cmd,
            cwd=self.build_dir,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE)

        await asyncio.gather(
            self.process_stream(proc.stdout),
            self.process_stream(proc.stderr),
        )

        self.synth_done()
        self.build_done()

        if os.path.isfile(self.output_file):
            self.phase = "Copying output file"
            await run_cmd_async("cp", "-p", self.output_file, os.path.join(self.output, self.outname+self.output_ext))
            self.phase = "Zipping output file"
            await run_cmd_async("zip", self.outname+".zip", self.outname+self.output_ext, cwd=self.output)
            self.phase = "Done"
        else:
            self.phase = "Failed"

        self.elapsed_time = datetime.datetime.now() - self.start_time

    async def process_stream(self, stream):
        while True:
            line = await stream.readline()
            if not line:
                break
            line = line.decode('utf-8').strip()

            self.scan_log_line(line)

    def scan_log_line(self, line):
        pass


class VivadoBuild(Build):
    def __init__(self, design, build_dir, prefix, output):
        super().__init__(design, build_dir, prefix, output)

        self.settings_file = config['vivado'].get('settings_file')
        self.build_cmd = "make"

        self.output_ext = ".bit"
        self.output_file = os.path.join(self.build_dir, "fpga"+self.output_ext)

        self.vivado_phase = "init"

    def scan_log_line(self, line):
        if line == "vivado -nojournal -nolog -mode batch -source create_project.tcl":
            self.vivado_phase = "init"
            self.phase = f"[{self.vivado_phase}] Creating Vivado project"
        if line == "vivado -nojournal -nolog -mode batch -source run_synth.tcl":
            self.vivado_phase = "synthesis"
            self.phase = f"[{self.vivado_phase}] Starting Vivado synthesis"
        if line == "vivado -nojournal -nolog -mode batch -source run_impl.tcl":
            self.synth_done()
            self.vivado_phase = "implementation"
            self.phase = f"[{self.vivado_phase}] Starting Vivado implementation"
        if line == "Starting Placer Task":
            self.vivado_phase = "implementation (placement)"
        if line == "Starting Routing Task":
            self.vivado_phase = "implementation (routing)"
        if line == "vivado -nojournal -nolog -mode batch -source generate_bit.tcl":
            self.vivado_phase = "bitfile generation"
            self.phase = f"[{self.vivado_phase}] Starting Vivado bitfile generation"

        if line.startswith("Start") or line.startswith("Running") or line.startswith("Phase"):
            self.phase = f"[{self.vivado_phase}] "+line.split("|", 1)[0].split(":", 1)[0].strip()

        m = re.search(r".*Timing Summary\s+\|\s+WNS=(\S+)\s+\|\s+TNS=(\S+)", line)
        if m:
            self.wns = m.group(1)
            self.tns = m.group(2)


class IseBuild(Build):
    def __init__(self, design, build_dir, prefix, output):
        super().__init__(design, build_dir, prefix, output)

        self.settings_file = config['ise'].get('settings_file')
        self.build_cmd = "make"

        self.output_ext = ".bit"
        self.output_file = os.path.join(self.build_dir, "fpga"+self.output_ext)

    def scan_log_line(self, line):
        if line.startswith('xst'):
            self.phase = "Running synthesis"
        elif line.startswith('ngdbuild'):
            self.synth_done()
            self.phase = "Running translate"
        elif line.startswith('map'):
            self.phase = "Running map"
        elif line.startswith('par'):
            self.phase = "Running placement and routing"
        elif line.startswith('trce'):
            self.phase = "Running timing analysis"
        elif line.startswith('bitgen'):
            self.phase = "Running bitfile generation"


class QuartusBuild(Build):
    def __init__(self, design, build_dir, prefix, output):
        super().__init__(design, build_dir, prefix, output)

        self.settings_file = config['quartus'].get('settings_file')
        self.build_cmd = "make"

        self.output_ext = ".sof"
        self.output_file = os.path.join(self.build_dir, "fpga"+self.output_ext)

    def scan_log_line(self, line):
        if line.startswith('quartus_ipgenerate'):
            self.phase = "Generating IP"
        elif line.startswith('quartus_map') or line.startswith('quartus_syn'):
            self.phase = "Running synthesis and mapping"
        elif line.startswith('quartus_fit'):
            self.synth_done()
            self.phase = "Running placement and routing"
        elif line.startswith('quartus_sta'):
            self.phase = "Running timing analysis"
        elif line.startswith('quartus_asm'):
            self.phase = "Running assembler"

        m = re.search(r"Worst-case setup slack is (\S+)", line)
        if m:
            self.wns = m.group(1)


class QuartusProBuild(QuartusBuild):
    def __init__(self, design, build_dir, prefix, output):
        super().__init__(design, build_dir, prefix, output)

        self.settings_file = config['quartus-pro'].get('settings_file')


async def monitor_status(jobs):
    start_time = datetime.datetime.now()

    while True:

        print("")

        done_count = 0

        for job in jobs:
            print(job.get_status())
            if job.elapsed_time is not None:
                done_count += 1

        s = f"Overall progress: {done_count}/{len(jobs)} jobs ({done_count/len(jobs)*100:.01f}%)"
        s += " ["+str(datetime.datetime.now() - start_time).split('.')[0]+"]"

        print(s)

        await asyncio.sleep(1)


async def main():
    config.read("build_images.ini")
    config.read("build_images_project.ini")
    config.read("build_images_local.ini")

    parser = argparse.ArgumentParser()
    parser.add_argument('--output_dir', type=str, default=None, help="Output directory")
    parser.add_argument('--prefix', type=str, default=config['general'].get('prefix', ''), help="Prefix")
    parser.add_argument('--clean', action='store_true', help="Clean")
    parser.add_argument('--parallel', type=int, default=config['general'].getint('parallel', 8), help="Parallel build runs")
    parser.add_argument('--synth_parallel', type=int, default=config['general'].getint('synth_parallel', 8), help="Parallel synthesis runs")

    args = parser.parse_args()

    version = run_cmd(["git", "describe", "--always", "--tags"])

    prefix = args.prefix+"-"+version

    if args.output_dir:
        output_dir = args.output_dir
    else:
        output_dir = os.path.abspath(os.path.join("bitfiles", prefix))

    print(f"Git version: {version}")
    print(f"Output directory: {output_dir}")

    print("Scanning...")

    scan_dirs = [x.strip() for x in config['general'].get('dirs', '').strip().split()]
    jobs = []

    if len(scan_dirs) == 0:
        scan_dirs = [os.getcwd()]

    for d in scan_dirs:
        path = os.path.abspath(d)
        for root, dirs, files in os.walk(path):
            for file in files:
                if file == 'Makefile' and os.path.basename(root).startswith('fpga'):
                    # found a makefile

                    design = os.path.relpath(root, path).split(os.sep)
                    if len(scan_dirs) > 1:
                        design = [d]+design

                    #design = [x for x in design if x != 'fpga']
                    #design = [x.removeprefix('fpga').strip("_") for x in design]

                    lst = []
                    for s in design:
                        if s.startswith('fpga'):
                            s = s[4:]
                        s = s.strip('_')
                        if not s:
                            continue
                        lst.append(s)
                    design = lst

                    if os.path.exists(os.path.join(root, "..", "common", "vivado.mk")):
                        # Vivado
                        jobs.append(VivadoBuild(design, root, prefix, output_dir))

                    if os.path.exists(os.path.join(root, "..", "common", "xilinx.mk")):
                        # ISE
                        jobs.append(IseBuild(design, root, prefix, output_dir))

                    if (os.path.exists(os.path.join(root, "..", "common", "altera.mk")) or
                            os.path.exists(os.path.join(root, "..", "common", "quartus.mk"))):
                        # Quartus Prime
                        jobs.append(QuartusBuild(design, root, prefix, output_dir))

                    if (os.path.exists(os.path.join(root, "..", "common", "quartus_pro.mk"))):
                        # Quartus Prime Pro
                        jobs.append(QuartusProBuild(design, root, prefix, output_dir))

    jobs.sort(key=lambda job: job.design)

    print(f"Found {len(jobs)} design variants")

    print("Building...")

    os.makedirs(output_dir, exist_ok=True)

    build_sem = asyncio.Semaphore(args.parallel)
    synth_sem = asyncio.Semaphore(args.synth_parallel)

    job_coros = []

    for job in jobs:
        if args.clean:
            job.build_cmd = "make clean"

        job_coros.append(asyncio.create_task(job.run(build_sem, synth_sem)))

    status = asyncio.create_task(monitor_status(jobs))

    await asyncio.wait(job_coros)

    await asyncio.sleep(1)

    status.cancel()

    run_cmd(["./collect_utilization.py",
        "--csv", os.path.join(output_dir, "utilization.csv"),
        "--log", os.path.join(output_dir, "utilization.txt")
    ])


if __name__ == '__main__':
    asyncio.run(main())
