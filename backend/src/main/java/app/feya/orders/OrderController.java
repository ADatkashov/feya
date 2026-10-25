package app.feya.orders;

import app.feya.common.Lang;
import app.feya.common.PageResponse;
import app.feya.security.Auth;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/orders")
public class OrderController {
    private final OrderService orders;

    public OrderController(OrderService orders) {
        this.orders = orders;
    }

    @PostMapping
    @Transactional
    public ResponseEntity<OrderDtos.OrderDetail> create(@Valid @RequestBody OrderDtos.CreateOrderRequest req,
                                                        @RequestHeader(value = "Idempotency-Key", required = false) String key) {
        OrderService.Created c = orders.create(Auth.userId(), req, key);
        return ResponseEntity.status(c.replayed() ? HttpStatus.OK : HttpStatus.CREATED).body(orders.detail(c.order()));
    }

    @GetMapping
    @Transactional(readOnly = true)
    public PageResponse<OrderDtos.OrderSummary> list(@RequestParam(defaultValue = "0") int page,
                                                     @RequestParam(defaultValue = "20") int size) {
        return PageResponse.of(orders.list(Auth.userId(), page, size), orders::summary);
    }

    @GetMapping("/{id}")
    public OrderDtos.OrderDetail get(@PathVariable UUID id) {
        return orders.get(Auth.userId(), id);
    }

    @PostMapping("/{id}/cancel")
    public OrderDtos.OrderDetail cancel(@PathVariable UUID id, @RequestBody(required = false) OrderDtos.CancelRequest req,
                                        Lang lang) {
        return orders.cancelByCustomer(Auth.userId(), id, req == null ? null : req.reason(), lang);
    }
}
