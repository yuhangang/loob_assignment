package cart

import (
	"context"
	"errors"
	"reflect"
	"testing"
)

type mockCartRepository struct {
	items               []CartItem
	upserted            CartItem
	updatedID           int64
	updated             CartItem
	removedID           int64
	cleared             bool
	getErr              error
	upsertErr           error
	updateErr           error
	removeErr           error
	clearErr            error
	lastOverrideStoreID int
}

func (m *mockCartRepository) GetCart(ctx context.Context, userID, countryID string, overrideStoreID int) ([]CartItem, error) {
	m.lastOverrideStoreID = overrideStoreID
	if m.getErr != nil {
		return nil, m.getErr
	}
	return m.items, nil
}

func (m *mockCartRepository) UpsertCartItem(ctx context.Context, item CartItem) (CartItem, error) {
	m.upserted = item
	if m.upsertErr != nil {
		return CartItem{}, m.upsertErr
	}
	return item, nil
}

func (m *mockCartRepository) UpdateCartItem(ctx context.Context, itemID int64, item CartItem) (CartItem, error) {
	m.updatedID = itemID
	m.updated = item
	if m.updateErr != nil {
		return CartItem{}, m.updateErr
	}
	return item, nil
}

func (m *mockCartRepository) RemoveCartItem(ctx context.Context, itemID int64, userID, countryID string) error {
	m.removedID = itemID
	return m.removeErr
}

func (m *mockCartRepository) ClearCart(ctx context.Context, userID, countryID string) error {
	m.cleared = true
	return m.clearErr
}

func TestUpsertItemSortsCustomizationIDsAndReturnsHydratedCart(t *testing.T) {
	repo := &mockCartRepository{
		items: []CartItem{
			{
				ID:               9,
				UserID:           "u1",
				CountryID:        "MY",
				StoreID:          2,
				MenuItemID:       4,
				Quantity:         1,
				CustomizationIDs: []int{3, 7},
				Name:             "Milk Tea",
				Options: []CartItemOption{
					{ID: 3, GroupID: 1, Code: "REG", Name: "Regular", IsAvailable: true},
				},
				IsAvailable: true,
			},
		},
	}
	svc := NewService(repo, "")

	resp, err := svc.UpsertItem(context.Background(), "MY", CartItemRequest{
		UserID:           "u1",
		StoreID:          2,
		MenuItemID:       4,
		Quantity:         1,
		CustomizationIDs: []int{7, 3},
	})
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(repo.upserted.CustomizationIDs, []int{3, 7}) {
		t.Fatalf("CustomizationIDs = %v, want sorted [3 7]", repo.upserted.CustomizationIDs)
	}
	if got := resp.Items[0].Options[0].Name; got != "Regular" {
		t.Fatalf("hydrated option name = %q, want Regular", got)
	}
}

func TestUpdateItemReplacesExistingLine(t *testing.T) {
	repo := &mockCartRepository{
		items: []CartItem{{ID: 10, UserID: "u1", CountryID: "MY", StoreID: 2, MenuItemID: 4, Quantity: 2, CustomizationIDs: []int{1, 8}}},
	}
	svc := NewService(repo, "")

	_, err := svc.UpdateItem(context.Background(), "MY", 10, CartItemUpdateRequest{
		UserID:           "u1",
		StoreID:          2,
		MenuItemID:       4,
		Quantity:         2,
		CustomizationIDs: []int{8, 1},
	})
	if err != nil {
		t.Fatal(err)
	}
	if repo.updatedID != 10 {
		t.Fatalf("updatedID = %d, want 10", repo.updatedID)
	}
	if !reflect.DeepEqual(repo.updated.CustomizationIDs, []int{1, 8}) {
		t.Fatalf("updated CustomizationIDs = %v, want [1 8]", repo.updated.CustomizationIDs)
	}
}

func TestUpdateItemValidatesRequest(t *testing.T) {
	svc := NewService(&mockCartRepository{}, "")

	_, err := svc.UpdateItem(context.Background(), "MY", 0, CartItemUpdateRequest{
		UserID: "u1", StoreID: 2, MenuItemID: 4, Quantity: 1,
	})
	if !errors.Is(err, ErrInvalidItemID) {
		t.Fatalf("err = %v, want ErrInvalidItemID", err)
	}

	_, err = svc.UpdateItem(context.Background(), "MY", 1, CartItemUpdateRequest{
		UserID: "", StoreID: 2, MenuItemID: 4, Quantity: 1,
	})
	if !errors.Is(err, ErrUserRequired) {
		t.Fatalf("err = %v, want ErrUserRequired", err)
	}
}

func TestRemoveItemMapsNotFound(t *testing.T) {
	svc := NewService(&mockCartRepository{removeErr: ErrNotFound}, "")

	_, err := svc.RemoveItem(context.Background(), "MY", "u1", 99)
	if !errors.Is(err, ErrNotFound) {
		t.Fatalf("err = %v, want ErrNotFound", err)
	}
}

func TestGetCartForwardsStoreOverrideForAvailabilityRefresh(t *testing.T) {
	repo := &mockCartRepository{}
	svc := NewService(repo, "")

	_, err := svc.GetCart(context.Background(), "MY", "u1", 42)
	if err != nil {
		t.Fatal(err)
	}
	if repo.lastOverrideStoreID != 42 {
		t.Fatalf("overrideStoreID = %d, want 42", repo.lastOverrideStoreID)
	}
}
