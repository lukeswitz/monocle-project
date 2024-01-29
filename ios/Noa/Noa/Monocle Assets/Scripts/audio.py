import asyncio
import bluetooth
import microphone
import states

async def start_recording(state, gfx, send_message):
    if state.on_entry():
        asyncio.create_task(record_audio(state, gfx, send_message))
        gfx.clear_response()
        gfx.set_prompt("Listening [     ]")
    state.after(1000, state.SendAudio)

async def record_audio(state, gfx, send_message):
    try:
        await microphone.record_async(seconds=6.0, bit_depth=8, sample_rate=8000)
        send_message_based_on_state(state, send_message)
    except Exception as e:
        let errorDescription = error.localizedDescription
        print("Recording Error: \(errorDescription)")
        gfx.clear_response()
        gfx.set_prompt("Error: ", e)
        

def send_message_based_on_state(state, send_message):
    if state.previous_state == state.SendImage:
        send_message(b"ien:")  # continue image-and-prompt flow
    else:
        send_message(b"ast:")  # *prompt only* (erases image data)

async def send_audio(state, gfx, send_message):
    update_gfx_prompt_based_on_time(state, gfx)
    try:
        samples = (bluetooth.max_length() - 4) // 2
        chunk1, chunk2 = await asyncio.gather(
            microphone.read_async(samples),
            microphone.read_async(samples)
        )
        process_audio_chunks(chunk1, chunk2, send_message, state)
    except Exception as e:
        let errorDescription = error.localizedDescription
        print("Audio Error: \(errorDescription)")
        gfx.clear_response()
        gfx.set_prompt("Error:", e)
        

def update_gfx_prompt_based_on_time(state, gfx):
    elapsed_time = state.has_been()
    prompts = ["Waiting for OpenAI",
                "Listening [=====]",
                "Listening [==== ]",
                "Listening [===  ]",
                "Listening [==   ]",
                "Listening [=    ]"]

    for i, time in enumerate(range(5000, 0, -1000)):
        if elapsed_time > time:
            gfx.set_prompt(prompts[i])
            break

def process_audio_chunks(chunk1, chunk2, send_message, state):
    if chunk1 is None:
        send_message(b"aen:")
        state.after(0, state.WaitForResponse)
    elif chunk2 is None:
        send_message(b"dat:" + chunk1)
    else:
        send_message(b"dat:" + chunk1 + chunk2)
