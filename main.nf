#!/usr/bin/env nextflow
nextflow.enable.dsl=2
params.publish_dir_mode = 'copy'
params.samplesheet = false
params.enable_conda = false
params.collect = true
params.flye_mode = "--nano-hq"
params.out = './results'

include { COLLECT_READS } from './modules/local/collect_reads/main'
include { ALIGN_TO_BAM as ALIGN_TO_REF } from './modules/align/main'
include { ALIGN_TO_BAM as ALIGN_TO_ASSEMBLY } from './modules/align/main'
include { BAM_INDEX_STATS_SAMTOOLS as BAM_STATS_REF } from './modules/bam_sort_stat/main'
include { BAM_INDEX_STATS_SAMTOOLS as BAM_STATS_ASSEMBLY} from './modules/bam_sort_stat/main'
include { FLYE } from './modules/flye/main'    
include { QUAST } from './modules/quast/main'

workflow {
    // Sample sheet layout:
    // sample, readpath, ref_fasta, ref_gff
    ch_input = Channel.fromPath(params.samplesheet) 
                        .splitCsv(header:true)
    in_reads = ch_input.map(row -> [row.sample, row.readpath])

    if(params.collect) {
    // COLLECT
    // Collect reads from fastq.gz into single fastq

    // view for debug
    // in_reads.view()
    COLLECT_READS(in_reads)
    in_reads = COLLECT_READS.out.combined_reads
    }

    // Asssembly using FLYE
    ch_flye_assembly = Channel.empty()
    FLYE(in_reads, params.flye_mode)
    ch_flye_assembly = FLYE.out.fasta

    // Map reads to reference
    ch_map_ref_in = in_reads
              .join(ch_input)
              .map(row -> [row.sample, row.combined_reads, row.ref_fasta])
    // View for debug
    ch_map_ref_in.view()

    ch_aln_to_ref = Channel.empty()
    ALIGN_TO_REF(ch_map_ref_in)
    ch_aln_to_ref = ALIGN_TO_REF.out.alignment
    BAM_STATS_REF(ch_aln_to_ref)

    // Remap reads to flye assembly
    map_assembly = in_reads
                   .join(ch_flye_assembly) 
    // View for debug
    map_assembly.view()
    ch_aln_to_assembly = Channel.empty()
    ALIGN_TO_ASSEMBLY(map_assembly)
    ch_aln_to_assembly = ALIGN_TO_ASSEMBLY.out.alignment
    BAM_STATS_ASSEMBLY(ch_aln_to_assembly)

    // prepare for quast
    quast_in = ch_flye_assembly
               .join(ch_input)
               .map(row -> [row.sample, row.fasta, row.ref_fasta, row.ref_gff])
               .join(ch_aln_to_ref)
               .join(ch_aln_to_assembly)
    quast_in.view()
    QUAST(quast_in, use_gff = true, use_fasta = true)
}

   