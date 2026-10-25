package app.feya.address;

import app.feya.common.ApiException;
import app.feya.delivery.DeliveryService;
import app.feya.identity.PhoneNumbers;
import app.feya.security.Auth;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/addresses")
public class AddressController {
    public record AddressRequest(@Size(max = 60) String label, @NotBlank @Size(max = 80) String city,
                                 @NotBlank @Size(max = 160) String street, @NotBlank @Size(max = 20) String building,
                                 @Size(max = 20) String apartment, @Size(max = 20) String entrance,
                                 @Size(max = 20) String floor, @Size(max = 40) String intercom,
                                 @Size(max = 120) String recipientName, @Size(max = 24) String recipientPhone,
                                 @Size(max = 500) String instructions,
                                 @DecimalMin("-90") @DecimalMax("90") BigDecimal latitude,
                                 @DecimalMin("-180") @DecimalMax("180") BigDecimal longitude,
                                 boolean makeDefault) {}

    public record AddressDto(UUID id, String label, String city, String street, String building, String apartment,
                             String entrance, String floor, String intercom, String recipientName,
                             String recipientPhone, String instructions, BigDecimal latitude, BigDecimal longitude,
                             boolean isDefault, boolean deliverable, UUID zoneId) {}

    private final AddressRepository addresses;
    private final DeliveryService delivery;

    public AddressController(AddressRepository addresses, DeliveryService delivery) {
        this.addresses = addresses;
        this.delivery = delivery;
    }

    @GetMapping
    public List<AddressDto> list() {
        return addresses.findByUserIdAndDeletedFalseOrderByDefaultAddressDescCreatedAtDesc(Auth.userId())
                .stream().map(this::dto).toList();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public AddressDto create(@Valid @RequestBody AddressRequest req) {
        UUID userId = Auth.userId();
        Address a = new Address();
        a.setUserId(userId);
        apply(a, req);
        boolean first = addresses.findByUserIdAndDeletedFalseOrderByDefaultAddressDescCreatedAtDesc(userId).isEmpty();
        a = addresses.save(a);
        if (first || req.makeDefault()) {
            makeDefault(userId, a);
        }
        return dto(a);
    }

    @PutMapping("/{id}")
    @Transactional
    public AddressDto update(@PathVariable UUID id, @Valid @RequestBody AddressRequest req) {
        UUID userId = Auth.userId();
        Address a = find(id, userId);
        apply(a, req);
        if (req.makeDefault()) {
            makeDefault(userId, a);
        }
        return dto(a);
    }

    @PutMapping("/{id}/default")
    @Transactional
    public AddressDto setDefault(@PathVariable UUID id) {
        UUID userId = Auth.userId();
        Address a = find(id, userId);
        makeDefault(userId, a);
        return dto(a);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Transactional
    public void delete(@PathVariable UUID id) {
        UUID userId = Auth.userId();
        Address a = find(id, userId);
        a.setDeleted(true);
        boolean wasDefault = a.isDefaultAddress();
        a.setDefaultAddress(false);
        if (wasDefault) {
            addresses.findByUserIdAndDeletedFalseOrderByDefaultAddressDescCreatedAtDesc(userId).stream().findFirst()
                    .ifPresent(next -> next.setDefaultAddress(true));
        }
    }

    // Ownership is enforced by always querying with the authenticated user's id.
    private Address find(UUID id, UUID userId) {
        return addresses.findByIdAndUserIdAndDeletedFalse(id, userId).orElseThrow(() -> ApiException.notFound("Address"));
    }

    private void makeDefault(UUID userId, Address target) {
        addresses.findByUserIdAndDeletedFalseOrderByDefaultAddressDescCreatedAtDesc(userId)
                .forEach(x -> x.setDefaultAddress(x.getId().equals(target.getId())));
    }

    private void apply(Address a, AddressRequest r) {
        if ((r.latitude() == null) != (r.longitude() == null)) {
            throw ApiException.badRequest("INVALID_COORDINATES", "Both latitude and longitude are required");
        }
        a.setLabel(blankToNull(r.label()));
        a.setCity(r.city().trim());
        a.setStreet(r.street().trim());
        a.setBuilding(r.building().trim());
        a.setApartment(blankToNull(r.apartment()));
        a.setEntrance(blankToNull(r.entrance()));
        a.setFloor(blankToNull(r.floor()));
        a.setIntercom(blankToNull(r.intercom()));
        a.setRecipientName(blankToNull(r.recipientName()));
        a.setRecipientPhone(r.recipientPhone() == null || r.recipientPhone().isBlank() ? null
                : PhoneNumbers.normalize(r.recipientPhone()));
        a.setInstructions(blankToNull(r.instructions()));
        a.setLatitude(r.latitude());
        a.setLongitude(r.longitude());
    }

    private AddressDto dto(Address a) {
        UUID zoneId = null;
        try {
            zoneId = delivery.resolveZone(a.getCity(), a.getLatitude(), a.getLongitude()).getId();
        } catch (ApiException notDeliverable) {
            // reported through deliverable=false
        }
        return new AddressDto(a.getId(), a.getLabel(), a.getCity(), a.getStreet(), a.getBuilding(), a.getApartment(),
                a.getEntrance(), a.getFloor(), a.getIntercom(), a.getRecipientName(), a.getRecipientPhone(),
                a.getInstructions(), a.getLatitude(), a.getLongitude(), a.isDefaultAddress(), zoneId != null, zoneId);
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }
}
