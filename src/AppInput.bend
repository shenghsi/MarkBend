import Base
import ./AppDocument.bend as App
import ./AppSave.bend as Save

# Input ending is not a close choice. The IO driver must retain a suspended
# document until a host wake or an explicit, separately checked close choice.
type Ended is Data:
  CloseSafe{document: App.Document}
  Suspended{document: App.Document}

type Wake is Data:
  Resumed{}
  Unavailable{}

type Continuation is Data:
  Running{document: App.Document}
  Retained{document: App.Document}

def from_close(decision: Save.CloseDecision) -> Ended:
  match decision:
    case Save.CloseNow{document}:
      CloseSafe{document}
    case Save.KeepOpen{document}:
      Suspended{document}
    case Save.SaveFirst{document}:
      Suspended{document}

def ended(document: App.Document) -> Ended:
  from_close(Save.close_requested(document))

# Unavailable service does not restart polling or supply permission to discard.
# This pure result cannot keep a process alive; the IO driver must retain it.
def resume(document: App.Document, wake: Wake) -> Continuation:
  match wake:
    case Resumed{}:
      Running{document}
    case Unavailable{}:
      Retained{document}
