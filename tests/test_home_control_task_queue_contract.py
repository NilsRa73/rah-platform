from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HOME = ROOT / 'RAH-HOME-CONTROL.html'


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f'Mangler oppgavekø-kontrakt: {label}: {needle!r}')


def forbid(text: str, needle: str, label: str) -> None:
    if needle in text:
        raise AssertionError(f'Utsatt funksjon ser ut til å være implementert: {label}: {needle!r}')


def main() -> None:
    text = HOME.read_text(encoding='utf-8')

    require(text, 'Lokal kø. Ingen automatisk kjøring fra siden ennå.', 'køen er eksplisitt lokal/manuell')
    require(text, 'id="addTask"', 'legg til testoppgave')
    require(text, 'id="clearTasks"', 'tøm kø')
    require(text, 'id="stopTasks"', 'stopp alle')
    require(text, 'data-task="${i}"', 'fjern enkeltoppgave')

    require(text, "addTask.onclick=()=>{const previousTasks=clone(state.tasks)", 'legg til tar rollback-kopi')
    require(text, "state.tasks.push({name:`Testoppgave ${state.tasks.length+1}`,status:'Venter'})", 'legg til endrer bare lokal kø')
    require(text, 'if(!save())state.tasks=previousTasks', 'legg til rulles tilbake ved lagringsfeil')

    require(text, "document.querySelectorAll('[data-task]')", 'fjern-knapper bindes lokalt')
    require(text, 'const previousTasks=clone(state.tasks);state.tasks.splice(+b.dataset.task,1)', 'fjern tar rollback-kopi før mutasjon')
    require(text, 'if(!save())state.tasks=previousTasks', 'fjern rulles tilbake ved lagringsfeil')

    require(text, 'clearTasks.onclick=()=>{', 'tøm kø-handler')
    require(text, 'const previousTasks=clone(state.tasks);state.tasks=[]', 'tøm kø tar rollback-kopi')
    require(text, "if(save())showActionNotice('Nattoppgave-køen er tømt og lagret lokalt.');else state.tasks=previousTasks", 'tøm kø lagrer eller ruller tilbake')

    require(text, 'stopTasks.onclick=()=>{const previousTasks=clone(state.tasks)', 'stopp alle tar rollback-kopi')
    require(text, "state.tasks=state.tasks.map(t=>({...t,status:'Stoppet'}))", 'stopp alle endrer bare lokal status')
    require(text, 'if(!save())state.tasks=previousTasks', 'stopp alle rulles tilbake ved lagringsfeil')

    for token, label in (
        ('fetch(', 'HTTP-kall'),
        ('WebSocket(', 'WebSocket'),
        ('RTCPeerConnection', 'WebRTC'),
        ('navigator.bluetooth', 'Bluetooth'),
        ('navigator.usb', 'USB'),
    ):
        forbid(text, token, label)

    print('PASS: RAH Home Control local task queue rollback contract')


if __name__ == '__main__':
    main()
