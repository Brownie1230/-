"""Run the Roblox-mock test suite with Lua 5.4 (pip install lupa)."""
import os
import sys

from lupa.lua54 import LuaRuntime

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.dirname(here)
os.environ["RAT_ROOT"] = root
os.chdir(root)

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('package.path = "%s/?.lua;" .. package.path' % here)
failures = lua.execute('return dofile("%s/run_tests.lua")' % here)
mock = lua.eval('require("mock_roblox")')
n_fail = len(list(failures.values())) if failures else 0
n_err = len(list(mock.errors.values()))
sys.exit(1 if (n_fail or n_err) else 0)
