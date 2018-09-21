#!/usr/bin/python
import sys, os

def verify(_filename):
  if not os.path.exists(_filename):
    print "%s file is not found."%_filename
    sys.exit(1)
  else:
    f = open(_filename)
    while True:
      ln = f.readline()
      if not ln: break
      list(erc20, eos_account, eos_key, eos_amount) =  ln.replace('"','').replace('\n','').split(",")
      print "%s - %s - %s"%(eos_account, eos_key, eos_amount)
    f.close()
  
if __name__ == "__main__":
  if len(sys.argv) is 1:
    print "Ussage: %s [Filename]"%(sys.argv[0])
    sys.exit(1)

  verify(sys.argv[1])
