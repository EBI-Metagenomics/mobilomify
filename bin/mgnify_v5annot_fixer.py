#!/usr/bin/env python
import warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)
warnings.filterwarnings("ignore", category=FutureWarning)

from Bio import SeqIO
import argparse
import sys
import os.path
import glob


##### This script add the protein IDs missing in the gff file generated by V5 annotation pipeline of MGnify
##### Alejandra Escobar, EMBL-EBI
##### March 2, 2023

parser = argparse.ArgumentParser(
        description='This script add the protein IDs missing in the gff file generated by V5 annotation pipeline of MGnify. Please provide the path to the following input files:')
parser.add_argument('--func_gff', type=str, help='V5 pipeline functional annotation file (gff)')
parser.add_argument('--aa', type=str, help='The protein sequences in fasta format')
args = parser.parse_args()


### Setting up variables
annot=args.func_gff
aa_seq=args.aa


### Saving the aminoacid coordinates
protein_coord={}
if os.path.isfile(aa_seq):
    for record in SeqIO.parse(aa_seq, "fasta"):
        description=str(record.description)
        if ' ' in description:
            start=description.split(' ')[2]
            end=description.split(' ')[4]
            strand=description.split(' ')[6].replace('-1','-').replace('1','+')
        else:
            start=description.split('_')[1]
            end=description.split('_')[2]
            strand=description.split('_')[3]
        contig=description.split('_')[0]
        prot_key=(contig,start,end,strand)
        protein_coord[prot_key]=str(record.id)


### correcting the gff file
head, tail = os.path.split(annot)
with open('corr_'+tail,'w') as to_gff:
    if os.path.isfile(annot):
        with open(annot,'r') as input_file:
            for line in input_file:
                if not line.startswith('#'):
                    contig,seq_source,seq_type,start,end,score,strand,phase,attr=line.rstrip().split('\t')
                    comp_key=(contig,start,end,strand)
                    if comp_key in protein_coord.keys():
                        new_id=protein_coord[comp_key]
                        attr=attr.split(';')
                        attr.pop(0)
                        attr=';'.join(attr)
                        new_attr='ID='+protein_coord[comp_key]+';'+attr
                        new_line=contig,seq_source,seq_type,start,end,score,strand,phase,new_attr
                        new_line='\t'.join(new_line)
                        to_gff.write(new_line+'\n')
                    else:
                        print('No protein ID in faa file for '+line)
                else:
                    to_gff.write(line)



