import { logger } from '../../logger';
import { AiProvider } from './types';
import { AnthropicProvider } from './anthropic-provider';
import { GeminiProvider } from './gemini-provider';

export * from './types';

const PROVIDER_FACTORIES: Record<string, () => AiProvider> = {
  anthropic: () => new AnthropicProvider(),
  gemini: () => new GeminiProvider(),
};

let cached: AiProvider | undefined;

export function getAiProvider(): AiProvider {
  if (cached) return cached;

  const raw = (process.env.AI_PROVIDER ?? '').trim().toLowerCase();
  const key = raw || 'anthropic';
  const factory = PROVIDER_FACTORIES[key];

  if (!factory) {
    logger.warn({ area: 'ai', provider: key }, 'Unknown AI_PROVIDER — falling back to "anthropic"');
    cached = PROVIDER_FACTORIES.anthropic();
  } else {
    cached = factory();
  }

  return cached;
}
