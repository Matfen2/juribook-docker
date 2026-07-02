#!/bin/sh
# ═══════════════════════════════════════════════════════════
#  Provisioning des topics Kafka de JuriBook
#
#  Lancé une fois au démarrage de l'infra (service kafka-init dans
#  docker-compose.yml), après que le broker soit healthy. Idempotent
#  (--if-not-exists) : peut être relancé sans casser un cluster déjà
#  provisionné.
#
#  8 topics du cahier des charges. Réplication 1 partout (broker
#  unique en dev/KRaft, passer à 3 en prod avec un cluster multi-broker).
# ═══════════════════════════════════════════════════════════
set -e

BOOTSTRAP="kafka:29092"
SEVEN_DAYS_MS=604800000

echo "Attente de la disponibilité du broker..."
kafka-topics --bootstrap-server "$BOOTSTRAP" --list > /dev/null

# ── Topics standards : 3 partitions, rétention opérationnelle 7 jours ──
# Suffisant pour rejouer/debugger un consumer en retard, sans laisser
# le disque grossir indéfiniment sur des événements métier courants.
STANDARD_TOPICS="booking-events slot-events lawyer-events review-events search-events document-events abuse-events"

for topic in $STANDARD_TOPICS; do
  echo "Provisioning $topic..."
  kafka-topics --bootstrap-server "$BOOTSTRAP" \
    --create --if-not-exists \
    --topic "$topic" \
    --partitions 3 \
    --replication-factor 1 \
    --config "retention.ms=$SEVEN_DAYS_MS"
done

# ── audit-events : rétention infinie ────────────────────────────────
# Journal d'audit immutable à valeur probatoire (UC-K1 du cahier des
# charges : traçabilité complète, conformité légale, preuve en cas de
# litige). Ne doit jamais être purgé automatiquement, contrairement
# aux autres topics métier.
echo "Provisioning audit-events (rétention infinie)..."
kafka-topics --bootstrap-server "$BOOTSTRAP" \
  --create --if-not-exists \
  --topic audit-events \
  --partitions 3 \
  --replication-factor 1 \
  --config retention.ms=-1 \
  --config retention.bytes=-1

echo ""
echo "Tous les topics ont été provisionnés :"
kafka-topics --bootstrap-server "$BOOTSTRAP" --list

echo ""
echo "Détail des configs :"
for topic in $STANDARD_TOPICS audit-events; do
  echo "--- $topic ---"
  kafka-topics --bootstrap-server "$BOOTSTRAP" --describe --topic "$topic"
done