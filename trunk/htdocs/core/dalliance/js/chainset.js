/* jshint ignore:start */
/* -*- mode: javascript; c-basic-offset: 4; indent-tabs-mode: nil -*- */

// 
// Dalliance Genome Explorer
// (c) Thomas Down 2006-2010
//
// chainset.js: liftover support
//

"use strict";

if (typeof(require) !== 'undefined') {
    var das = require('./das');
    var DASSource = das.DASSource;
    var DASSegment = das.DASSegment;

    var utils = require('./utils');
    var pusho = utils.pusho;
    var shallowCopy = utils.shallowCopy;

    var parseCigar = require('./cigar').parseCigar;

    var bin = require('./bin');
    var URLFetchable = bin.URLFetchable;

    var bbi = require('./bigwig');
    var makeBwg = bbi.makeBwg;

    var Promise = require('es6-promise').Promise;
}

function Chainset(conf, srcTag, destTag, coords) {
    if (typeof(conf) == 'string') {
        this.uri = conf;
        this.srcTag = srcTag;
        this.destTag = destTag;
        this.coords = coords;
    } else {
        this.uri = conf.uri;
        this.srcTag = conf.srcTag;
        this.destTag = conf.destTag;
        this.coords = shallowCopy(conf.coords);
        this.type = conf.type;
        this.credentials = conf.credentials;
    }

    this.chainsBySrc = {};
    this.chainsByDest = {};
    this.postFetchQueues = {};

    if (this.type == 'bigbed') {
        this.chainFetcher = new BBIChainFetcher(this.uri, this.credentials);
    } else {
        this.chainFetcher = new DASChainFetcher(this.uri, this.srcTag, this.destTag);
    }
};

Chainset.prototype.exportConfig = function() {
    return {
        uri: this.uri,
        srcTag: this.srcTag,
        destTag: this.destTag,
        coords: this.coords,
        type: this.type,
        credentials: this.credentials
    };
}

Chainset.prototype.mapPoint = function(chr, pos) {
    var chains = this.chainsBySrc[chr] || [];
    for (var ci = 0; ci < chains.length; ++ci) {
        var c = chains[ci];
        if (pos >= c.srcMin && pos <= c.srcMax) {
            var cpos;
            if (c.srcOri == '-') {
                cpos = c.srcMax - pos;
            } else {
                cpos = pos - c.srcMin;
            }
            var blocks = c.blocks;
            for (var bi = 0; bi < blocks.length; ++bi) {
                var b = blocks[bi];
                var bSrc = b[0];
                var bDest = b[1];
                var bSize = b[2];
                if (cpos >= bSrc && cpos <= (bSrc + bSize)) {
                    var apos = cpos - bSrc;

                    var dpos;
                    if (c.destOri == '-') {
                        dpos = c.destMax - bDest - apos;
                    } else {
                        dpos = apos + bDest + c.destMin;
                    }
                    return {seq: c.destChr, pos: dpos, flipped: (c.srcOri != c.destOri)}
                }
            }
        }
    }
    return null;
}

Chainset.prototype.unmapPoint = function(chr, pos) {
    var chains = this.chainsByDest[chr] || [];
    for (var ci = 0; ci < chains.length; ++ci) {
        var c = chains[ci];
        if (pos >= c.destMin && pos <= c.destMax) {
            var cpos;
            if (c.srcOri == '-') {
                cpos = c.destMax - pos;
            } else {
                cpos = pos - c.destMin;
            }    
            
            var blocks = c.blocks;
            for (var bi = 0; bi < blocks.length; ++bi) {
                var b = blocks[bi];
                var bSrc = b[0];
                var bDest = b[1];
                var bSize = b[2];

                if (cpos >= bDest && cpos <= (bDest + bSize)) {
                    var apos = cpos - bDest;

                    var dpos = apos + bSrc + c.srcMin;
                    var dpos;
                    if (c.destOri == '-') {
                        dpos = c.srcMax - bSrc - apos;
                    } else {
                        dpos = apos + bSrc + c.srcMin;
                    }
                    return {seq: c.srcChr, pos: dpos, flipped: (c.srcOri != c.destOri)}
                }
            }
            // return null;
        }
    }
    return null;
}

Chainset.prototype.sourceBlocksForRange = function(chr, min, max, callback) {
    if (!this.chainsByDest[chr]) {
        var fetchNeeded = !this.postFetchQueues[chr];
        var thisCS = this;
        pusho(this.postFetchQueues, chr, function() {
            thisCS.sourceBlocksForRange(chr, min, max, callback);
        });
        if (fetchNeeded) {
            this.chainFetcher.fetchChains(chr).then(function(chains, err) {
                if (!thisCS.chainsByDest)
                    thisCS.chainsByDest[chr] = [];
                for (var ci = 0; ci < chains.length; ++ci) {
                    var chain = chains[ci];
                    pusho(thisCS.chainsBySrc, chain.srcChr, chain);
                    pusho(thisCS.chainsByDest, chain.destChr, chain);
                }
                if (thisCS.postFetchQueues[chr]) {
                    var pfq = thisCS.postFetchQueues[chr];
                    for (var i = 0; i < pfq.length; ++i) {
                        pfq[i]();
                    }
                    thisCS.postFetchQueues[chr] = null;
                }
            });
        }
    } else {
        var srcBlocks = [];
        var chains = this.chainsByDest[chr] || [];
        for (var ci = 0; ci < chains.length; ++ci) {
            var c = chains[ci];
            if (min <= c.destMax && max >= c.destMin) {
                var cmin, cmax;
                if (c.srcOri == '-') {
                    cmin = c.destMax - max;
                    cmax = c.destMax - min;
                } else {
                    cmin = min - c.destMin;
                    cmax = max - c.destMin;
                }

                var blocks = c.blocks;
                for (var bi = 0; bi < blocks.length; ++bi) {
                    var b = blocks[bi];
                    var bSrc = b[0];
                    var bDest = b[1];
                    var bSize = b[2];

                    if (cmax >= bDest && cmin <= (bDest + bSize)) {
                        var amin = Math.max(cmin, bDest) - bDest;
                        var amax = Math.min(cmax, bDest + bSize) - bDest;

                        if (c.destOri == '-') {
                            srcBlocks.push(new DASSegment(c.srcChr, c.srcMax - bSrc - amax, c.srcMax - bSrc - amin));
                        } else {
                            srcBlocks.push(new DASSegment(c.srcChr, c.srcMin + amin + bSrc, c.srcMin + amax + bSrc));
                        }
                    }
                }
            }
        }
        callback(srcBlocks);
    }
}

function DASChainFetcher(uri, srcTag, destTag) {
    this.source = new DASSource(uri);
    this.srcTag = srcTag;
    this.destTag =destTag;
}

DASChainFetcher.prototype.fetchChains = function(chr, _min, _max) {
    var thisCS = this;

    return new Promise(function(resolve, reject) {
        thisCS.source.alignments(chr, {}, function(aligns) {
            var chains = [];

            for (var ai = 0; ai < aligns.length; ++ai) {
                var aln = aligns[ai];
                for (var bi = 0; bi < aln.blocks.length; ++bi) {
                    var block = aln.blocks[bi];
                    var srcSeg, destSeg;
                    for (var si = 0; si < block.segments.length; ++si) {
                        var seg = block.segments[si];
                        var obj = aln.objects[seg.object];
                        if (obj.dbSource === thisCS.srcTag) {
                            srcSeg = seg;
                        } else if (obj.dbSource === thisCS.destTag) {
                            destSeg = seg;
                        }
                    }
                    if (srcSeg && destSeg) {
                        var chain = {
                            srcChr:     aln.objects[srcSeg.object].accession,
                            srcMin:     srcSeg.min|0,
                            srcMax:     srcSeg.max|0,
                            srcOri:     srcSeg.strand,
                            destChr:    aln.objects[destSeg.object].accession,
                            destMin:    destSeg.min|0,
                            destMax:    destSeg.max|0,
                            destOri:    destSeg.strand,
                            blocks:     []
                        }

                        var srcops = parseCigar(srcSeg.cigar), destops = parseCigar(destSeg.cigar);

                        var srcOffset = 0, destOffset = 0;
                        var srci = 0, desti = 0;
                        while (srci < srcops.length && desti < destops.length) {
                            if (srcops[srci].op == 'M' && destops[desti].op == 'M') {
                                var blockLen = Math.min(srcops[srci].cnt, destops[desti].cnt);
                                chain.blocks.push([srcOffset, destOffset, blockLen]);
                                if (srcops[srci].cnt == blockLen) {
                                    ++srci;
                                } else {
                                    srcops[srci].cnt -= blockLen;
                                }
                                if (destops[desti].cnt == blockLen) {
                                    ++desti;
                                } else {
                                    destops[desti] -= blockLen;
                                }
                                srcOffset += blockLen;
                                destOffset += blockLen;
                            } else if (srcops[srci].op == 'I') {
                                destOffset += srcops[srci++].cnt;
                            } else if (destops[desti].op == 'I') {
                                srcOffset += destops[desti++].cnt;
                            }
                        }

                        chains.push(chain);
                    }
                }
            }
            resolve(chains);
        });
    });
}

function BBIChainFetcher(uri, credentials) {
    var self = this;
    this.uri = uri;
    this.credentials = credentials;

    this.bwg = new Promise(function(resolve, reject) {
        makeBwg(new URLFetchable(self.uri, {credentials: self.credentials}), function(bwg, err) {
            if (bwg) {
                resolve(bwg);
            } else {
                reject(err);
            }
        });
    });

    this.bwg.then(function(bwg, err) {
        if (err)
            console.log(err);
    });
}

function pi(x) {
    return parseInt(x);
}

function bbiFeatureToChain(feature) {
    var chain = {
        srcChr:     feature.srcChrom,
        srcMin:     parseInt(feature.srcStart),
        srcMax:     parseInt(feature.srcEnd),
        srcOri:     feature.srcOri,
        destChr:    feature.segment,
        destMin:    feature.min - 1,     // Convert back from bigbed parser
        destMax:    feature.max,
        destOri:    feature.ori,
        blocks:     []
    };
    var srcStarts = feature.srcStarts.split(',').map(pi);
    var destStarts = feature.destStarts.split(',').map(pi);
    var blockLengths = feature.blockLens.split(',').map(pi);
    for (var bi = 0; bi < srcStarts.length; ++bi) {
        chain.blocks.push([srcStarts[bi], destStarts[bi], blockLengths[bi]]);
    }

    return chain;
}

BBIChainFetcher.prototype.fetchChains = function(chr, _min, _max) {
    return this.bwg.then(function(bwg, err) {
        if (!bwg)
            throw Error("No BWG");

        return new Promise(function(resolve, reject) {
            bwg.getUnzoomedView().readWigData(chr, 1, 30000000000, function(feats) {
                resolve(feats.map(bbiFeatureToChain));
            });
        });
    });
};

if (typeof(module) !== 'undefined') {
    module.exports = {
        Chainset: Chainset
    };
}

/* jshint ignore:end */
