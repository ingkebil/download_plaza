#!/bin/bash

# Please save the genes onto the workbench. This will create a list of genes
# with their respective homologues and orthologues.
# When loging in via this script, we add two more entries in the $cookiejar to
# convince PLAZA that we are human and not a script. It might be that one needs
# to change the values of the last column: e.g. Q2FrZQ... to match the updated
# values of your login. You can figure out the new value by loging in and
# examining the cookies that come with this site.

#############
# variables #
#############

username= # your username urlescaped
password= # your password

# when creating a new workbench, it gets assigned a number visible in the url
workbench= # an integer

#############
# constants #
#############

base_url=http://bioinformatics.psb.ugent.be
logon_url=$base_url/plaza/versions/plaza_v3_dicots/workbench/logon 
orth_url=$base_url/plaza/versions/plaza_v3_dicots/genes/index_reduced/gf/on
workbench_url=$base_url/plaza/versions/plaza_v3_dicots/workbench/subset/$workbench/sp/ath

# yes .. we are a browser, trust me. (we need to fool their webserver or we are being denied with 403)
fake_header='User-Agent:Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:30.0) Gecko/20100101 Firefox/30.0'
cookiejar=cookies.txt

###################
# ok, here we go! #
###################

# logon -- and save the cokie information so we can use it for subsequent requests
echo -n 'Loging in ...'
wget --header "$fake_header" --save-cookies $cookiejar --post-data "_method=POST&wb_login=$username&wb_pass=$password&submit=true" -q --output-document /dev/null $logon_url
# get last line of the cookiejar and extract the timestamp
timestamp=`tail -n 1 $cookiejar | cut -f5`
# add two more cookies so PLAZA would believe we are human
echo ".bioinformatics.psb.ugent.be	TRUE	/plaza/versions/plaza_v3_dicots/	FALSE	$timestamp	plaza_workbench[full_login]	Q2FrZQ%3D%3D.xsh6CFp9h0TSwzockuSPSwERrruKGfggeg%3D%3D" >> $cookiejar
echo "bioinformatics.psb.ugent.be	TRUE	/plaza/versions/plaza_v3_dicots/	FALSE	$timestamp	CAKEPHP	CAKEPHP55kohknht1m3e80d7mg8mviou1" >> $cookiejar
echo 'Done.'

# get the workbench | filter the ortholog names
echo -n 'Getting orthologous genes ...'
orthologous_genes=()
for ortholog in `wget --header "$fake_header" --load-cookies $cookiejar -qO- $workbench_url | sed -n 's/.*\(ORTHO.*\)".*/\1/p'`
do
    orthologous_genes=("${orthologous_genes[@]}" `wget --header "$fake_header" --load-cookies $cookiejar -qO- $orth_url/$ortholog/limit:1000 | sed -n 's/.*plaza\/versions\/plaza_v3_dicots\/genes\/view\/\(.*\)".*/\1/p' | grep -v '^AT'`)
done
echo 'Done.'
# sort and make uniq
echo -n 'sort -u ...'
orthologous_genes=(`printf '%s\n' "${orthologous_genes[@]}"|sort -u`)
echo 'Done.'

# Ok. The website disables downloads of over 30 sequences at the time. So I made
# this to download the sequences in batches of 30. It seems, this limit is
# _only_ on the website, so just download everything with a simple wget
######
# slice the array up in slices of 30, as this is the limit with which we can download sequences
#for i in {0..993..30}
#do
#    echo -n "Getting genes sequences $i ..."
#    # remove the genes from the workbench
#    wget --header "$fake_header" --load-cookies $cookiejar -qO- $base_url/plaze/versions/plaza_v4_dicots/workbench/delete_subset/$workbench/all
#
#    genes=${orthologous_genes[@]:$i:30} # slice!
#    genes=${genes[@]// /%20} # replace spaces with their url escaped sequence
#
#    # add the new genes
#    wget --header "$fake_header" --load-cookies $cookiejar -qO- --post-data "exp_id=91&_method=POST&genes_input=$genes" -qO- $base_url/plaza/versions/plaza_v3_dicots/workbench/add_genes
#
#    # download their sequences
#    wget --header "$fake_header" --load-cookies $cookiejar -qO- --post-data "_method=POST&download_type=upstream" --output-document ${i}.fasta $base_url/plaza/versions/plaza_v3_dicots/workbench/export_sequences/$workbench
#    echo 'Done.'
#done
######

echo -n 'Adding genes to workbench...'
orthologous_genes=${orthologous_genes[@]// /%20} # replace spaces with their url escaped sequence
# add the new genes
wget --header "$fake_header" --load-cookies $cookiejar --post-data "exp_id=$workbench&_method=POST&genes_input=$orthologous_genes" -q --output-document /dev/null $base_url/plaza/versions/plaza_v3_dicots/workbench/add_genes 
echo 'Done.'

# download their sequences
echo -n "Getting gene sequences ..."
wget --header "$fake_header" --load-cookies $cookiejar -q --post-data "_method=POST&download_type=upstream" --output-document orthologs.fasta $base_url/plaza/versions/plaza_v3_dicots/workbench/export_sequences/$workbench
echo 'Done.'
