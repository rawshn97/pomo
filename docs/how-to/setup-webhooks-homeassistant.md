# How-To: Set Up RGB Webhooks for Home Assistant

This guide explains how to connect Pomo to smart home platforms like Home Assistant to synchronize ambient lighting with your Pomodoro focus states.

---

## 1. How Pomo Webhooks Work

Whenever the timer changes state or ticks, Pomo can dispatch asynchronous HTTP POST requests to one or more user-configured URLs.

Each webhook payload contains a 3-element RGB integer array representing the active timer ring color:

```json
{
  "rgb": [255, 0, 156]
}
```

The RGB values change dynamically based on the active lap:
- **Work Lap**: Vibrant color indicating focused deep work.
- **Short Break**: Calming accent color for quick rest.
- **Long Break**: Relaxing hue indicating an extended break.

Multiple endpoints can be configured simultaneously using comma-separated URLs.

---

## 2. Set Up Home Assistant Automation

In your Home Assistant instance, create an automation to listen for Pomo webhook events and update your desk or room lighting.

Add the following automation to your `automations.yaml` (or create it through the Home Assistant UI under **Settings -> Automations & Scenes**):

```yaml
alias: Pomo Timer Lighting Sync
description: "Syncs desk light color with active Pomo Pomodoro state."
trigger:
  - platform: webhook
    allowed_methods:
      - POST
      - PUT
    local_only: true
    webhook_id: "pomo-timer-state"
condition:
  - condition: device
    type: is_on
    device_id: REPLACE_WITH_DEVICE_ID
    entity_id: light.desk_light
    domain: light
action:
  - service: light.turn_on
    data:
      rgb_color: "{{ trigger.json['rgb'] }}"
      transition: 1
    target:
      entity_id: light.desk_light
mode: single
```

Replace `REPLACE_WITH_DEVICE_ID` and `light.desk_light` with your smart bulb entity ID.

---

## 3. Configure Webhooks in Pomo

1. Open Pomo and navigate to the **Settings** tab.
2. Scroll to the **Webhooks** section.
3. Toggle **Enable Webhooks** to **ON**.
4. Configure the webhook endpoints:
   - **Work Start Webhook**: URL to trigger when starting a work session.
   - **Short Break Start Webhook**: URL to trigger when entering a short break.
   - **Long Break Start Webhook**: URL to trigger when entering a long break.
   - **Lap End Webhook**: URL to trigger when any lap completes.
   - **Tick Webhook**: (Optional) Fires once per second during active countdowns for continuous lighting animations.
5. Enter your Home Assistant webhook URL:
   ```
   http://homeassistant.local:8123/api/webhook/pomo-timer-state
   ```

---

## 4. Test the Integration

You can simulate a Pomo webhook payload directly from your terminal using `curl`:

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"rgb": [0, 200, 255]}' \
  http://homeassistant.local:8123/api/webhook/pomo-timer-state
```

Observe whether your desk light smoothly transitions to cyan. Once confirmed, start a focus sprint in Pomo to see your lighting change automatically.
