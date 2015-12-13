import readline,rlcompleter,sys
import pdb, traceback, pprint

readline.parse_and_bind("tab: complete")
sys.ps1="py> "

def exc_hook(exc_type, exc_val, tb):
  traceback.print_exception(exc_type, exc_val, tb)
  if tb is not None:
    pdb.post_mortem(tb)

sys.excepthook=exc_hook

try:
    from pygments import highlight
    from pygments.lexers import PythonLexer
    from pygments.formatters import TerminalFormatter
except ImportError: highlight=None

import inspect

def l(obj):
  src,lnr=inspect.getsourcelines(obj)
  print "File: %s line %d"%(inspect.getsourcefile(obj), lnr)
  if highlight is not None:
    print highlight("".join(src), PythonLexer(), TerminalFormatter())
  else: print "".join(src)
