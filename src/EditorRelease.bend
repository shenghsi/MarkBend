import Base
import ./StoredEditor.bend as Editor
import ./SceneRelease.bend as Scene
import ./TextRelease.bend as Text

type Queue is Data:
  Queue{scene: Maybe<&2, Scene.Queue>, text: Maybe<&2, Text.Queue>}

type Progress is Data:
  Complete{}
  Pending{queue: Queue}

def begin(session: Editor.Session) -> Queue:
  match session:
    case Editor.Session{editor, storage}:
      Queue{Some{Scene.begin(editor)}, Some{Text.begin_history(storage)}}

def scene_progress(value: Scene.Progress) -> Maybe<&2, Scene.Queue>:
  match value:
    case Scene.Complete{}:
      None{}
    case Scene.Pending{queue}:
      Some{queue}

def text_progress(value: Text.Progress) -> Maybe<&2, Text.Queue>:
  match value:
    case Text.Complete{}:
      None{}
    case Text.Pending{queue}:
      Some{queue}

def scene_step(budget: Nat, value: Maybe<&2, Scene.Queue>) -> Maybe<&2, Scene.Queue>:
  match value:
    case None{}:
      None{}
    case Some{queue}:
      scene_progress(Scene.step(budget, queue))

def text_step(budget: Nat, value: Maybe<&2, Text.Queue>) -> Maybe<&2, Text.Queue>:
  match value:
    case None{}:
      None{}
    case Some{queue}:
      text_progress(Text.step(budget, queue))

def progress(scene: Maybe<&2, Scene.Queue>, text: Maybe<&2, Text.Queue>) -> Progress:
  match scene text:
    case None{} None{}:
      Complete{}
    case scene text:
      Pending{Queue{scene, text}}

# Budget applies separately to each half. Independent ownership permits
# parallel work; pending queues must remain owned until both halves finish.
def step(+budget: Nat, queue: Queue) -> Progress:
  match queue:
    case Queue{scene, text}:
      next_scene next_text = scene_step(budget, scene) text_step(budget, text)
      progress(next_scene, next_text)

def continued(value: Progress, more: Queue -> IO(Progress)) -> IO(Progress):
  match value:
    case Complete{}:
      IO.pure(Progress, Complete{})
    case Pending{queue}:
      more(queue)

# Yield between bounded steps. Exhausted fuel returns ownership to the caller;
# it must continue draining rather than discard the pending result.
def drain_with_pause(fuel: Nat, +budget: Nat, +pause: U32, queue: Queue) -> IO(Progress):
  match fuel:
    case 0n:
      IO.pure(Progress, Pending{queue})
    case 1n+remaining:
      do IO<Progress>:
        ready : Nat <- IO.now()
        result : Progress = step(budget, queue)
        IO.sleep(pause)
        continued(result, q => drain_with_pause(remaining, budget, pause, q))

def drain(fuel: Nat, budget: Nat, queue: Queue) -> IO(Progress):
  drain_with_pause(fuel, budget, 1, queue)
