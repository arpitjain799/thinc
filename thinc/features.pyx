from libc.stdint cimport uint64_t
from cymem.cymem cimport Pool

from murmurhash.mrmr cimport hash64

from .api cimport Example


DEF MAX_TEMPLATE_LEN = 10


cdef class ConjunctionExtracter:
    """Extract composite features from a sequence of atomic values, according to
    the schema specified by a list of templates.
    """
    def __init__(self, nr_atom, templates):
        self.mem = Pool()
        self.nr_atom = nr_atom
        # Value that indicates the value has been "masked", e.g. it was pruned
        # as a rare word. If a feature contains any masked values, it is dropped.
        templates = tuple(sorted(set([tuple(sorted(f)) for f in templates])))
        self.nr_templ = len(templates) + 1
        self.templates = <TemplateC*>self.mem.alloc(len(templates), sizeof(TemplateC))
        # Sort each feature, and sort and unique the set of them
        cdef int i, j, idx
        for i, indices in enumerate(templates):
            assert len(indices) < MAX_TEMPLATE_LEN
            for j, idx in enumerate(sorted(indices)):
                self.templates[i].indices[j] = idx
            self.templates[i].length = len(indices)

    def __call__(self, Example eg):
        eg.c.nr_feat = self.set_features(eg.c.features, eg.c.atoms)

    cdef int set_features(self, FeatureC* feats, const atom_t* atoms) nogil:
        cdef TemplateC* templ
        cdef FeatureC* feat
        feats[0].key = 1
        feats[0].val = 1
        cdef bint seen_non_zero
        cdef int templ_id
        cdef int n_feats = 1
        cdef int i
        for templ_id in range(self.nr_templ-1):
            templ = &self.templates[templ_id]
            seen_non_zero = False
            for i in range(templ.length):
                templ.atoms[i] = atoms[templ.indices[i]]
                seen_non_zero = seen_non_zero or templ.atoms[i]
            if seen_non_zero:
                feat = &feats[n_feats]
                feat.key = hash64(templ.atoms, templ.length * sizeof(templ.atoms[0]),
                                  templ_id)
                feat.val = 1
                n_feats += 1
        return n_feats
