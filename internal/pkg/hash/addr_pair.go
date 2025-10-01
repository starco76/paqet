package hash

import (
	"hash/maphash"
	"sync"
)

var hasherPool = sync.Pool{
	New: func() any {
		return &maphash.Hash{}
	},
}

func AddrPair(localAddr, targetAddr string) uint64 {
	h := hasherPool.Get().(*maphash.Hash)
	defer hasherPool.Put(h)

	h.Reset()
	h.WriteString(localAddr)
	h.WriteString(targetAddr)
	return h.Sum64()
}
