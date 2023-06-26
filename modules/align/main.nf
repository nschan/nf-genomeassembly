include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process ALIGN {
    tag "$meta"
    label 'process_low'
       publishDir "${params.out}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), publish_id:meta) }

    input:
        tuple val(meta), path(reads), path(reference)

    output:
        tuple val(meta), path("*.sam"), emit: alignment

    script:
        """
        minimap2 -ax map-ont ${reference} ${reads}  > ${meta}.sam
        """
}

process ALIGN_TO_BAM {
    tag "$meta"
    label 'process_low'
       publishDir "${params.out}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), publish_id:meta) }

    input:
        tuple val(meta), path(reads), path(reference)

    output:
        tuple val(meta), path("*.bam"), emit: alignment

    script:
        def genome = reference.simpleName()
        """
        minimap2 -ax map-ont ${reference} ${reads} | samtools sort -o ${meta}_$genome.bam
        """
}