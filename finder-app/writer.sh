if [ -z "$1" ] || [ -z "$2" ]
  then
    echo "There are expected 2 arguments: a file and a string"
    exit 1
fi

dir=$(dirname $1)
mkdir -p $dir
echo "$2" > $1
