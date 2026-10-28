#!/usr/bin/python3.6

''' 
********************************************************************************************
# Organisation : Wafer Space Semiconductor Technologies
# Guide : Sakthivel Veerappalam, Director - Engineering (DV) (mail : sakthivelv@waferspace.com)
# Author : Mahantha Deeksha S B, Design Engineer Trainee (DV) (mail : mahanthab@waferspace.com)
#
# Copyright (c) 2023, Wafer Space Semiconductor Technologies
# All rights reserved
# Redistribution and use in source code or binary form is allowed only if the following conditions are met
#  ** To use the code as is, prior intimation is required  
#  ** To use any part of the code proper endorsements and credits must be given to author
# **********************************************************************************************


# ******************************************************************************
# Python script for questasim simulator
# ****************************************************************************** 
# Separate libraries are created for design files and tb
# design_work and tb_work
  If files are not modified then are not recompiled
'''


import os
import subprocess
import argparse
import sys

call = subprocess

description="Python script for questa sim execution"
parser = argparse.ArgumentParser(description)

parser.add_argument("-d","--design_comp",help="compiles design files",type=int,default=0)
parser.add_argument("-tb","--tb_comp",help="compiles tb files",type=int,default=0)
parser.add_argument("-gui_mode","--GUI",help="for GUI mode of execution",type=int,default=0)
parser.add_argument("-comp_mode","--COMPILER",help="for execution in compiler mode",type=int,default=0)
parser.add_argument("-d_lib","--design_library",help="creates design work library",type=int,default=0)
parser.add_argument("-tb_lib","--tb_library",help="creates tb work library",type=int,default=0)
parser.add_argument("-clean","--CLEAN",help="removes all the work library",type=int,default=0)

cmd_args = parser.parse_args()

GUI=0
DESIGN_LIB="/home/mahanthab/projects/ahb_uvc/design/design_work"
TB_LIB="/home/mahanthab/projects/ahb_uvc/tb/tb_work"
RTL="/home/mahanthab/projects/ahb_uvc/design/"
RTL_COMP_LOG="/home/mahanthab/projects/ahb_uvc/sim/design.log"
TB="/home/mahanthab/projects/ahb_uvc/tb/"
TB_COMP_LOG="/home/mahanthab/projects/ahb_uvc/sim/tb.log"
TB_TOP="/home/mahanthab/projects/ahb_uvc/tb/tb.tops"
WLF="/home/mahanthab/projects/ahb_uvc/sim/vsim.wlf"
SIM_LOG="/home/mahanthab/projects/ahb_uvc/sim/simulation.log"
COVER="/home/mahanthab/projects/ahb_uvc/coverage/"



# Design files compilation 
if cmd_args.design_comp : 
   call.call(["vlog","-work",DESIGN_LIB,"-incr","-f",RTL+"design_list.f","+"+"cover","-l",RTL_COMP_LOG,"+"+"fcover"])

# TB files compilation
if cmd_args.tb_comp:
   call.call(["vlog","-work",TB_LIB,"-incr","-f",TB+"tb_list.f","-l",TB_COMP_LOG,"-writetoplevels",TB_TOP]) 

if cmd_args.GUI:
# Simulation in GUI mode
   call.call(["vsim","-L",DESIGN_LIB,"-lib",TB_LIB,"-f",TB_TOP,"-wlf",WLF,"-l",SIM_LOG,"-novopt","+UVM_TESTNAME=ahb_base_test","-do","run.do"])
if cmd_args.COMPILER:
# Simulation in compiler mode
   call.call(["vsim","-c","-L",DESIGN_LIB,"-lib",TB_LIB,"-f",TB_TOP,"-wlf",WLF,"-l",SIM_LOG,"ahb_base_test.log","-assertfile","assert_log.txt","-coverage","+UVM_TESTNAME=ahb_base_test","-do",'"'+"coverage save -onexit",COVER+"/ahb_base_test"+".ucdb;run","-all"+'"'])


# To create separate design and tb library directories
# Libraries are created only once
if cmd_args.design_library: 
   call.call(["vlib",DESIGN_LIB])

if cmd_args.tb_library:
   call.call(["vlib",TB_LIB])


# To clean all the files created during compilation and simulation
if cmd_args.CLEAN:
   call.call(["rm","-rf",DESIGN_LIB,TB_LIB,RTL_COMP_LOG,TB_COMP_LOG,SIM_LOG,WLF,TB_TOP])
else:
   print("FOR OPTIONS PLEASE USE COMMANDS  python python_script_name.py -h or python3.6 python_script_name.py -h")
   print("EXITING")
   sys.exit(1)
