package app.feya.common;

import app.feya.security.Auth;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import java.time.Instant;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuditService {
    @PersistenceContext
    private EntityManager em;

    @Transactional(propagation = Propagation.REQUIRED)
    public void record(String action, String entityType, Object entityId, String details) {
        record(Auth.userIdOrNull(), Auth.primaryRoleOrNull(), action, entityType, entityId, details);
    }

    @Transactional(propagation = Propagation.REQUIRED)
    public void record(UUID actorId, String actorRole, String action, String entityType, Object entityId, String details) {
        AuditEvent e = new AuditEvent();
        e.setActorId(actorId);
        e.setActorRole(actorRole);
        e.setAction(action);
        e.setEntityType(entityType);
        e.setEntityId(entityId == null ? null : entityId.toString());
        e.setDetails(details == null ? null : (details.length() > 1000 ? details.substring(0, 1000) : details));
        e.setCreatedAt(Instant.now());
        em.persist(e);
    }
}
