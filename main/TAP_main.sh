#!/usr/bin/env bash
# # This script uses the read depth GC corrected files generated by Read_depth_GCcorrection.sh as input to asses  wether the TEs provided via 
# # GFF file  present an absence in compa
# of the reference.
set -u
usage() { echo "$0 usage:
This script uses the read depth GC corrected file generated by Read_depth_GCcorrection.sh  set as input (-i) to asses  wether the TEs provided via 
GFF file (-a)  present an absence in comparition with the read depth GC corrected file generated by Read_depth_GCcorrection.sh  set as reference (-r).
You can set a size treshold  in bp ( -t) for the features in the GFF file to do the comparition (set it always  equal or bigger than 300. Ex -t 300).
For each unique TE ID present in the GFF file  runs a non-parametric test (Wilcoxin_test.R) to evaulate if the deviations in RD between input and 
reference are  significant enough to consider that TE an absence candidate in the input sample. This table is  then filtered by FDR corected p-value 
and low RD TEs to give  a final table of detected TAPS.
" && grep " .)\ #" $0; exit 0; }

[ $# -eq 0 ] && usage

while getopts ":hi:r:a:t:S:" arg; do
  case $arg in
    i) # path to input file (.depthGCcorrected.regions_filtered.bed.gz format )
      input_file=${OPTARG}
      ;;
    r) #  path to  the reference RD file (.depthGCcorrected.regions_filtered.bed.gz format )
      reference_file=${OPTARG}
      ;;
    a) # path to TE annotation file (gff3 format)
      TE_anno=${OPTARG}
      ;;
    t) # Minimun TE size to be  considered (integer => 300)
      threshold=${OPTARG}
      ;;
    S) # path to  the R script(Rscript format)
      Rscript=${OPTARG}
      ;;
    h | *) # Display help.
      usage
      exit 0
      ;;
  esac
done
#files for testing purposes:
#input_file="/ebio/abt6_projects8/Tarvense_TE/data/Tarvense_TE_pops/CNV/RCcorrected_samples/TA_NL_01_04_F1_HC0_M1_1.depthGCcorrected.regions_filtered.bed.gz"
#reference_file="/ebio/abt6_projects8/Tarvense_TE/data/Tarvense_TE_pops/CNV/RCcorrected_reference/88473_88774_GCcorected_depth_averaged_Regionsfilt.bed.gz"
#TE_anno="/ebio/abt6_projects8/Tarvense_TE/data/Tarvense_TE_pops/CNV/annotations/sorted.final.TEs_covF.gff3"
#Rscritp="./T_test.R"
### RSCRIPT in the same folder as this script!!!!

## Temporal files
temp_total_input=$(mktemp --suffix=.txt temp_total_input.XXXXXXXX)
temp_total_ref=$(mktemp --suffix=.txt temp_total_reference.XXXXXXXX)

temp_TE=$(mktemp --suffix=.gff temp_TEanno.XXXXXXXX)
temp_Rinput=$(mktemp --suffix=.tsv temp_Rinput.XXXXXXXX)
temp_input_prior=$(mktemp --suffix=.tsv temp_input_prior.XXXXXXXX)
temp_ref_prior=$(mktemp --suffix=.tsv temp_ref_prior.XXXXXXXX)


## Calcualte the total RD for each file:
zcat ${input_file}     | grep -v "^#" | awk '{x+=$5} END{print x}' > ${temp_total_input}
zcat ${reference_file} | grep -v "^#" |  awk '{x+=$5} END{print x}' > ${temp_total_ref}

## Filter TEs by threshold var length.
awk -v threshold=$threshold '{ if($5-$4 > threshold) print $0}'  ${TE_anno} | bedtools sort -i - > ${temp_TE}

## Create R input, both the reference file and the input file bins are associated to their corresponding  TE by its ID and then both files are joined.
zcat $input_file | bedtools  intersect  -wao -a ${temp_TE}  -b - | awk 'BEGIN{ OFS=FS="\t"}{ print $9,$14}' >  ${temp_input_prior}
zcat $reference_file | bedtools  intersect  -wao -a ${temp_TE}  -b - | awk 'BEGIN{ OFS=FS="\t"}{ print $9,$14}' >  ${temp_ref_prior}
cut -f2 ${temp_input_prior} | paste  ${temp_ref_prior} -  | sed '1 i\TE_ID\tref\tinput'  > ${temp_Rinput}

## Fed this to the  WIlcox Rscript
Rscript ${Rscript}  ${temp_Rinput} ${temp_total_input}  ${temp_total_ref}  ${temp_TE} ${input_file}

## Cleanup
rm ${temp_TE}
rm ${temp_Rinput}
rm ${temp_input_prior}
rm ${temp_ref_prior}
rm ${temp_total_input}
rm ${temp_total_ref}
