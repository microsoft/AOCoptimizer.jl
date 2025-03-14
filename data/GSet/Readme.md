# The GSet data set

The GSet data set is a collection of graphs for benchmarking MaxCut algorithms.
It has been used extensively to evaluate the performance of various heuristic algorithms
and non-traditional computing paradigms.

The files in this directory have been retrieved from [Yinyu Ye's web site](http://web.stanford.edu/~yyye/yyye/Gset/).
The initial set of problems are described in the [paper](https://opus4.kobv.de/opus4-zib/files/306/SC-97-37.pdf):

> *Christoph Helmberg and Franz Rendl*,
> **"A Spectral Bundle Method for Semidefinite Programming"**,
> Technical report SC 97-37. Konrad-Zuse-Zentrum für Informationstechnik Berlin, 1997.

The file `reference.csv` contains some reference solutions for the problems in this directory.

## Input format

The first line contains the number of vertices and edges, and each of the following lines corresponds to each edge.
Each edge line contains the identities of the vertices and the weight of the edge.
The vertices take identities starting from 1.
The edges are assumed to be undirected.
Often, there is an empty line at the end.
In most cases, the weight of the edge is just 1, but in some files it can be negative (-1).
