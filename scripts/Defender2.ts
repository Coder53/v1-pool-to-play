import { AutotaskEvent, SentinelTriggerEvent } from 'defender-autotask-utils';

// Example for an Autotask being triggered by a Sentinel
export async function handler(event: AutotaskEvent) {
  const match = event.request.body as SentinelTriggerEvent;
  console.log(`Matched tx ${match.hash}`);
}