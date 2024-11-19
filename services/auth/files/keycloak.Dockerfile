# FROM quay.io/keycloak/keycloak:nightly AS builder
#
# WORKDIR /opt/keycloak
#
# ENV KC_DB=postgres
# ENV KC_METRICS_ENABLED=true
# ENV KC_HEALTH_ENABLED=true
# ENV KC_LOG_LEVEL=DEBUG
#
# # Copy the custom provider to the Keycloak provider directory
# COPY keycloak-epic-idp-1.1-SNAPSHOT.jar /opt/keycloak/providers/keycloak-epic-idp-1.1-SNAPSHOT.jar
# RUN /opt/keycloak/bin/kc.sh build  --spi-identity-provider-epic-oidc-enabled=true

FROM quay.io/keycloak/keycloak:nightly
# COPY --from=builder /opt/keycloak /opt/keycloak

ENV KC_DB=postgres
ENV KC_DB_USERNAME=postgres
ENV KC_METRICS_ENABLED=true
ENV KC_HEALTH_ENABLED=true
ENV KC_LOG_LEVEL=DEBUG
ENTRYPOINT [ "/opt/keycloak/bin/kc.sh" ]

