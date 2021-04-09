---
title: 'Makie.jl: High-performance plotting in Julia'
tags:
  - Julia
  - plotting
  - data visualization
  - GPU
  - OpenGL
authors:
  - name: Simon Danisch
    affiliation: 1
  - name: Julius Krumbiegel
    orcid: 0000-0002-8409-5590
    affiliation: 2
affiliations:
 - name: Beacon Biosignals
   index: 1
 - name: Department of Systems Neuroscience, University Medical Center Hamburg-Eppendorf
   index: 2
date: 10 April 2021
bibliography: paper.bib
---

# Summary

`Makie.jl` is a cross-platform plotting ecosystem for the Julia programming language, which enables researchers to create high-performance, GPU-powered, interactive visualizations, as well as publication-quality vector graphics with one unified interface.
The infrastructure based on `Observables.jl` allows users to express how a visualization depends on multiple parameters and data sources, which can then be updated live, either programmatically, or through sliders, buttons and other GUI elements.
A sophisticated layout system makes it easy to assemble complex figures.
It is designed to avoid common difficulties when aligning nested subplots of different sizes, or placing colorbars or legends freely without spacing issues.
`Makie.jl` leverages the Julia type system to automatically convert many kinds of input arguments which results in a very flexible API that reduces the need to manually prepare data.
Finally, users can extend every step of this pipeline for their custom types through Julia's powerful multiple dispatch mechanism, making Makie a highly productive and generic visualization system.

# Statement of need


# Acknowledgements

We acknowledge contributions from ...

# References