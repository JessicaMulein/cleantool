# cleantool
Verifies and removes files of the pattern *.extension.abcde
Requires bash shell and presumes '/' for path separator

My hard drive became littered with files of the format *.ext.aBcDE that were exact duplicates, so 
I wrote this tool to clean them up.

Options:
  -R : recursive
  -f : force rm on match
  -md5 : use MD5 instead of 'cmp', impacts runtime
  
 Usage:
  cd /Volumes/Macintosh HD/Users/foobar
  /path/to/cleantool.sh [-R,-f,-md5] [extension]
  
  If -R is provided, must not supply an extension.
  If no extension is provided, the working directory is cleaned.
  Default is to clean the working directory for the supplied extension.
