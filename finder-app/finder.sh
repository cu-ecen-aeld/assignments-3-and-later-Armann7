if [ -z "$1" ] || [ -z "$2" ]
  then
    echo "There are expected 2 arguments: a dir and a string"
    exit 1
fi

if ! [ -d $1 ]; then
  echo "Directory $1 is not exists."
fi

count_files=$(find $1 -type f | wc -l)
count_matches=$(grep -r "$2" "$1" | wc -l)
echo "The number of files are $count_files and the number of matching lines are $count_matches"

