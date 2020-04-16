#!/bin/bash

printhelpmessage() {
    cat <<-EOF
    Usage: markorphanreads.sh [--progress] [--remove] input.sortbyname.sam
    
EOF
}

[ $# -eq 0 ] && printhelpmessage && return 0

while test $# -gt 1; do
    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        printhelpmessage && return 0

    elif [ "$1" == "--progress" ]; then
        >&2 echo "  --progress flag specified. Showing progress bar."
        PRINTPROGRESS=1

    elif [ "$1" == "--remove" ]; then
        >&2 echo "  --remove flag specified. Removing orphaned reads."
        REMOVEORPHAN=1
    else
        >&2 echo "  $1 flag is not recognised. Ignoring..."

    fi
    shift
done

[ $PRINTPROGRESS ] && TOTALRAW=$(( `wc -l <$1` ))

awk -v REMOVEORPHAN=$REMOVEORPHAN -v TOTALRAW=$TOTALRAW -F"\t" '
BEGIN{
    OFS="\t"
    ONEHUNDREDTH=int( TOTALRAW/100 )
    ONEFOURTIETH=int( TOTALRAW/40 )
}
TOTALRAW&&FNR%ONEHUNDREDTH==0{
    PROGRESSPERCENT=(FNR/TOTALRAW)*100
    PROGRESS=int( FNR/ONEFOURTIETH )
    PROGRESSBAR="["

    for(i=1;i<=40;i++) {
        if(i<PROGRESS) {
            PROGRESSBAR=PROGRESSBAR"="
        } 
        if(i==PROGRESS) {
            PROGRESSBAR=PROGRESSBAR">"
        } 
        if(i>PROGRESS) {
            PROGRESSBAR=PROGRESSBAR" "
        }        
    }

    PROGRESSBAR=PROGRESSBAR"] "sprintf("%d%\n",PROGRESSPERCENT)
    printf PROGRESSBAR > "/dev/stderr"
    printf "\033[1A" > "/dev/stderr"
    #WRITEBACK=">&2 echo -en $'\''\\e\\r '\''"
    #system(WRITEBACK)
}
$0~/^@/{
    print
    next
}
{
    TOTAL++
    _[$1]++

    # Check if current entry has read_name matching the previous entry. If yes, write and move to next
    if($1==PREVNAME) {
        print PREVENTRY
        print

        PREVENTRY=""
        PREVNAME=""
        next
    } else {

        # Check if current entry mismatch previous entry. If yes, set proper_pair FLAG to off and write
        if(PREVNAME) {
            if(!REMOVEORPHAN) {
                delete ENTRYARRAY
                NEWENTRY=""
            
                split(PREVENTRY,ENTRYARRAY,"\t")
                if(and(0x2,ENTRYARRAY[2])) ENTRYARRAY[2]=ENTRYARRAY[2]-2

                for(i=1;i<=length(ENTRYARRAY);i++) {
                    NEWENTRY=NEWENTRY"\t"ENTRYARRAY[i]
                }
                print substr(NEWENTRY,2)

                PREVENTRY=""
                PREVNAME=""
            }
        }   

        # Store and move to next
        PREVENTRY=$0
        PREVNAME=$1
        next
    }
}
END{
    if(PREVNAME) {
        delete ENTRYARRAY
        NEWENTRY=""
        split(PREVENTRY,ENTRYARRAY,"\t")
        if(and(0x2,ENTRYARRAY[2])) ENTRYARRAY[2]=ENTRYARRAY[2]-2

        for(i=1;i<=length(ENTRYARRAY);i++) {
            NEWENTRY=NEWENTRY"\t"ENTRYARRAY[i]
        }
        print substr(NEWENTRY,2)
    }
    for(key in _) {
        __[_[key]]++
    }
    print "\nTotal number of reads:\t\t\t"TOTAL > "/dev/stderr"
    print "Total number of fragments:\t\t"length(_) > "/dev/stderr"
    for(key in __) {
        print "Number of alignments with "key" "(key<2?"read":"reads")":\t"__[key] > "/dev/stderr"
    }
}' $1