import Base
import ./RecoveryEntry.bend as Entry
import ./RecoveryRecord.bend as Record
import ./SaveState.bend as Save

type Selection is Data:
  InvalidIdentity{requested: List<&2, U32>, entries: List<&2, Entry.Entry>}
  Missing{}
  Unique{entry: Entry.Entry}
  Ambiguous{entries: List<&2, Entry.Entry>}

def classify(entries: List<&2, Entry.Entry>) -> Selection:
  match entries:
    case Nil{}:
      Missing{}
    case Con{entry, Nil{}}:
      Unique{entry}
    case entries:
      Ambiguous{entries}

def matches(requested: List<&2, U32>, entry: Entry.Entry) -> Bool:
  match entry:
    case Entry.Entry{key, state}:
      Save.bytes_equal(requested, key)

def retain(ok: Bool, entry: Entry.Entry, entries: List<&2, Entry.Entry>) -> List<&2, Entry.Entry>:
  match ok:
    case True{}:
      Con{entry, entries}
    case False{}:
      entries

def scan(entries: List<&2, Entry.Entry>, +requested: List<&2, U32>,
  found: List<&2, Entry.Entry>) -> Selection:
  match entries:
    case Nil{}:
      classify(List.reverse(&2, Entry.Entry, found))
    case Con{+entry, rest}:
      scan(rest, requested, retain(matches(requested, entry), entry, found))

def lookup_gate(ok: Bool, entries: List<&2, Entry.Entry>, requested: List<&2, U32>) -> Selection:
  match ok:
    case False{}:
      InvalidIdentity{requested, entries}
    case True{}:
      scan(entries, requested, Nil{})

# The host must supply validated decoded entries and retain unreadable or invalid
# files separately. Missing here means no match in this list, not no disk data.
# A filename hash is not document ownership. Duplicate ownership is ambiguous.
def lookup(entries: List<&2, Entry.Entry>, +requested: List<&2, U32>) -> Selection:
  lookup_gate(Entry.nonempty(requested) && Record.valid_bytes(requested), entries, requested)
