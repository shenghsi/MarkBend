import Base
import ./StoredEditor.bend as Editor

type Destination is Data:
  Untitled{}
  Requested{path: String}
  Resolved{requested: String, path: String, identity: List<&2, U32>}

type Document is Data:
  Document{destination: Destination, session: Editor.Session}

# Resolved is reserved for a host resolution result with a nonempty opaque
# identity. Requested is not permission to save. No identity comes from text.
def with_session(destination: Destination, session: Editor.Session) -> Document:
  Document{destination, session}
