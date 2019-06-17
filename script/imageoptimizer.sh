#!/bin/bash

usage()
{
  cat <<EO
    Usage: $0 -d <dir> [options]
    Script to optimize JPG and PNG images in a directory.
    Options:
EO
cat <<EO | column -s\& -t
    -d,  --dir <directory>              & Target directory (recursively) for optimization. 
                                        & Target file for optimization (jpg or png files). 
                                        & gif files should be converted to png for optimization using mogrify or convert. Currently not implemented. 
    -q, --quality <quality>             & Only applies to jgp files. Sets the maximum image quality factor (disables lossless optimization mode, which is by default enabled). 
                                        & This option will reduce quality of those source files that were saved using higher quality setting. 
                                        & While files that already have lower quality setting will be compressed using the lossless optimization method.
                                        & Valid values for quality parameter are: 0 - 100, default value 100. You should use 90 for websites. 
                                        & If configured, it also removes comments and exim data.
    -t, --time <number of days>         & Files for otimization width modified time less than <number of days>. 2 days by default.
                                         
    -s <size>, --max-size <size>        & Max size for images width or height.  Currently not implemented. Example:
                                        & mogrify.... 
    -h, --help                          & shows this help
EO
}


test_binaries()
{
  # test if binaries exists:
  if ! [ -x "$(command -v optipng)" ]; then
    echo "You need to execute sudo apt-get install optipng before running imageoptimizer.sh"
    exit -1
  fi
  if ! [ -x "$(command -v jpegoptim)" ]; then
    echo "You need to execute sudo apt-get install jpegoptim before running imageoptimizer.sh"
    exit -1
  fi
}

init_variables()
{
  QUALITY=100 # no quality loss
  TIME=2 # two days
}



optimize_image()
{

  # get file meta data

  MIMETYPE=`file -b --mime-type $1`
  ORIGSIZE=`stat -c%s $1`
  PREVIOUSSIZEREADABLE=`ls -lah $1 | awk '{ print $5}'`
  if [ "$MIMETYPE" == "image/jpeg" ]; then
    jpegoptim -m$QUALITY --strip-all $1 #> /dev/null
  elif [ "$MIMETYPE" == "image/png" ]; then
    optipng -quiet -o7 -preserve $1
    #optipng -quiet -force -o7 $1
    #advpng -q -z4 $1
    #pngcrush -q -rem gAMA -rem alla -rem cHRM -rem iCCP -rem sRGB -rem time $1 $1.tmp
    #mv $1.tmp $1
  fi

  # show final stats

  NEWSIZE=`stat -c%s $1`
  NEWSIZEREADABLE=`ls -lah $1 | awk '{ print $5}'`
  ((PERCENTCHANGE=100-(NEWSIZE*100/ORIGSIZE)))

  echo $1: compressed from $PREVIOUSSIZEREADABLE to $NEWSIZEREADABLE \($PERCENTCHANGE% saved\)
}

optimize_images()
{
  echo "***imageoptimizer has started***"
  # apply the compressimg script to every image file within the given directory
  # if the input is a single file, execute the script on it
  ORIGSIZEDIR=`du -sb $DIR | awk '{ print $1}'`
  PREVIOUSREADABLESIZEDIR=`du -sh $DIR | awk '{ print $1}'`
  IMAGES=$(find $DIR -mtime -$TIME -type f \( -name "*.jpeg" -or -name "*.jpg" -or -name "*.png" \)) # -exec ./prueba2 '{}' $QUALITY  \;
  IFS=$'\n' #so spaces won't bother inside filename
  for IMAGE in $IMAGES; do
    optimize_image $IMAGE
  done

  # generate stats
  NEWSIZE=`du -sb $DIR | awk '{ print $1}'`
  READABLESIZE=`du -sh $DIR | awk '{ print $1}'`
  ((PERCENTCHANGE=100-(NEWSIZE*100/ORIGSIZEDIR)))
  echo Directory $DIR is compress from $PREVIOUSREADABLESIZEDIR to $READABLESIZE \($PERCENTCHANGE%\)
  echo "***imageoptimezer has finished***"
}




#test_binaries
init_variables
  # evaluate entry args
  # make args an array, not a string
  args=( )

  # replace long arguments
  for arg; do
      case "$arg" in
          --dir)           args+=( -d ) ;;
          --quality)       args+=( -q ) ;;
          --size)          args+=( -s ) ;;
          --time)          args+=( -t ) ;;
          --help)          args+=( -h ) ;;
          *)               args+=( "$arg" ) ;;
      esac
  done
  # printf 'args before update : '; printf '%q ' "$@"; echo
  set -- "${args[@]}"
  # printf 'args after update  : '; printf '%q ' "$@"; echo

  # init_variables

  while getopts "d:q:s:t:h" OPTION; do
      : "$OPTION" "$OPTARG"
      # echo "optarg : $OPTARG"
      case $OPTION in
      h)
        usage
        exit 0
        ;;
      d)
        DIR=("$OPTARG")
        ;;
      q)
        QUALITY=("$OPTARG")
        ;;
      s)
        shift
        SIZE=("$OPTARG")
        ;;
      t)
        TIME=("$OPTARG")
        ;;      
      esac
  done

if [ -z "$DIR" ]; then
  usage
  exit -1
fi

if ! [ -d $DIR ]; then
  echo "Directory " $DIR "doesn't exists"
  exit -1
fi

optimize_images
