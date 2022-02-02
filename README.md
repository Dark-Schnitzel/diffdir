# diffdir
Shell Script for comparing 2 folders. 

Tested on BSD only at the moment. 

Usage: diffdir.sh folder1 folder2 ${options}

# Command Line Options:
    -s, --stats           Show Results/Stats at the End of the Run
    -c, --checksum        Compare files via checksum (files only)
    --diff                Show diff output. If Checksum and diff are used both, only the stats for diff will be shown (different checksum = diff in Content)
    --acls                Compare ACLs
    --missing             Missing Files
    --extattr             Compare extended Attributes
    -l, --link            Compare Link Targets
    -o, --owner           Compare Owner permissions
    -m, --mode            Compare Filemodes
    -t, --time            Compare Timestamps
    -a, --all             All the Options above combined (default)        
    -h, --help            Show this help section
    -d, --debug           Enable Debugging
    -v                    Verbose
