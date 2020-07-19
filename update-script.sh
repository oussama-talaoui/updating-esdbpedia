#!/bin/bash

# TODO
# More variables
# User friendly script

#--------------------- Start of the script ---------------------
# Along the execution of our script we calculate the time taken
start=`date +%s`

# variables definition
DATAPATH="vad"
GRAPH="<http://es.dbpedia.org>"
ACCOUNT="dba"
PASSWORD="dba"
DIR=$(dirname "$0")

# post request to a sparql end point using content in txt file and write the result to variable as list
QUERY=$(<"$DIR"/request.txt)

# retrieve downloadurls with sparql query
DOWNLOADURLS=`curl -X POST --data-urlencode query="$QUERY" --data-urlencode format="text/tab-separated-values"  "https://databus.dbpedia.org/repo/sparql"`

# remove double quotes " from downloadurls, because of wget scheme missing
DOWNLOADURLS=`echo $DOWNLOADURLS| sed 's/"//g'`
echo $DOWNLOADURLS

# remove previous data files
echo -n 'Deleting files... '
rm -f /usr/local/virtuoso/share/virtuoso/"$DATAPATH"/* & PID=$!
echo 'Done!'

# download files and append timestamp
for url in $DOWNLOADURLS; do
	echo "Downloading" $url
	current_time=$(date "+%Y.%m.%d-%H.%M.%S")
	#echo "Current Time : $current_time"
	filename=$(basename "$url")
	wget -q -c $url -O /usr/local/virtuoso/share/virtuoso/"$DATAPATH"/"$current_time.$filename" &
done
wait

# remove unneeded files
echo "Removing unneeded files."
rm -f /usr/local/virtuoso/share/virtuoso/"$DATAPATH"/*.file
rm -f /usr/local/virtuoso/share/virtuoso/"$DATAPATH"/*.pdf

# uncompress the bz2 files and delete them
printf "Uncompressing .bz2 files..."
ls /usr/local/virtuoso/share/virtuoso/"$DATAPATH"/*.bz2 | parallel bunzip2 & wait
echo 'Done!'

rm -f /usr/local/virtuoso/var/lib/virtuoso/db/virtuoso.lck

# running the virtuoso server if it's down and waiting for it to run before continuing
if netstat -tulpn | grep virtuoso-t
then
    echo "server running"
else
    echo "running the server..."
    virtuoso-t -f -c /usr/local/virtuoso/var/lib/virtuoso/db/virtuoso.ini &
    while ! netstat -tulpn | grep virtuoso-t
    do
	wait 5
    done
    echo "server running"
fi

# Create graph name file
echo "http://es.dbpedia.org" > /usr/local/virtuoso/share/virtuoso/vad/global.graph

# Clear the graph and the load list table, to load new data
# Large graphs can be cleared by changing the transaction log mode to autocommit on each operation, deleting the graph(s) or triples. This is easily done using the Virtuoso log_enable function, with the settings log_enable(3,1).

isql-v 1111 dba dba exec="log_enable(3,1);"
isql-v 1111 dba dba exec="DELETE FROM RDF_QUAD WHERE G = DB.DBA.RDF_MAKE_IID_OF_QNAME ('http://es.dbpedia.org');"
# isql-v 1111 dba dba exec="DELETE FROM rdf_quad WHERE g = iri_to_id ('http://es.dbpedia.org');"
isql-v 1111 dba dba exec="DELETE FROM DB.DBA.load_list;"
isql-v 1111 dba dba exec="ld_dir ('/usr/local/virtuoso/share/virtuoso/vad', '*.*', 'http://es.dbpedia.org');"

# Getting number of cores in the machine and running multiple Loaders using no cores / 2.5, to optimally parallelize the data load.
noperation=`echo $(nproc) / 2.5 | bc`
echo $noperation " multipe loader:"
echo "Running multiple Loaders:"
for (( c=1; c<=$noperation; c++ ))
do
	isql-v 1111 dba dba exec="rdf_loader_run();" &
done
wait

isql-v 1111 dba dba exec="checkpoint;"
# Showing the time taken to load the datasets to our graph
isql-v 1111 dba dba exec="select min(ll_started) as start, max(ll_done) as finish, datediff('second', min(ll_started), max(ll_done)) as delta from load_list where ll_graph like 'http://es.dbpedia.org';"
isql-v 1111 dba dba exec="SPARQL SELECT (COUNT(*) as ?Triples) FROM <http://es.dbpedia.org> WHERE { ?s ?p ?o };"
isql-v 1111 dba dba exec="SPARQL SELECT *  FROM <http://es.dbpedia.org> WHERE    {     ?s ?p ?o   } LIMIT 100 ;"

end=`date +%s`
runtime=$((end-start))
echo Running the script took $(($runtime / 60)) minutes.